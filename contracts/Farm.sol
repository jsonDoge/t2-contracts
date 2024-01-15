//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FarmSettings.sol";
import "./Product.sol";
import "./Seed.sol";
import "./Plot.sol";
import "./Dish.sol";
import "./Utils.sol";

/**
 * @dev Farm used to plant seeds, harvest products and convert products to seeds
 */
contract Farm {
    struct Plant {
        address owner;
        address seed;
        uint256 plotId;
        uint256 plantedBlockNumber;
        // TODO: don't store overgrowth block in each plant, move it to a constant
        uint256 overgrownBlockNumber;
        uint256 waterAbsorbed;
        uint256 _userPlantIdIndex; // used for easier cleanup
    }

    struct PlotWaterLog {
        uint256 blockNumber;
        uint256 level; // max -> PLOT_MAX_WATER
    }

    struct PlotView {
        address owner;
        Plant plant;
    }

    address private _farmSettings;
    address private _acceptedToken;

    mapping(uint256 => Plant) private plotPlant;
    mapping(uint256 => PlotWaterLog) private plotWaterLog;
    mapping(address => uint256[]) private userPlants;

    event HarvestNotEnoughWater(uint256 plotId, uint256 waterAbsorbed);
    event HarvestOvergrown(uint256 plotId);
    event HarvestSuccess(uint256 plotId);
    event PlotWaterUpdate(uint256 plotId, uint256 blockNumber, uint256 level);

    constructor(
        address farmSettings,
        address acceptedToken
    ) {
        _farmSettings = farmSettings;
        _acceptedToken = acceptedToken;
    }

    function buySeeds(address seed, uint256 quantity) public {
        require(quantity > 0, "QUANTITY_MUST_BE_GREATER_THAN_ZERO");
        require(FarmSettings(_farmSettings).isValidSeed(seed), "INVALID_SEED");

        IERC20(_acceptedToken).transferFrom(msg.sender, address(this), quantity);
        Seed(seed).mint(msg.sender, quantity);
    }

    // TODO: add method to buy multiple plots at once
    function buyPlot(uint256 plotId) public { 
        // openzeppelin already checks allowance
        IERC20(_acceptedToken).transferFrom(msg.sender, address(this), 1);

        Plot(getPlotAddr()).mint(msg.sender, plotId);

        uint256 plotMaxX = FarmSettings(_farmSettings).PLOT_AREA_MAX_X();
        uint256 plotMaxY = FarmSettings(_farmSettings).PLOT_AREA_MAX_Y();

        // TODO: cover plotWaterLog with tests
        if (plotWaterLog[plotId].blockNumber == 0) {
            plotWaterLog[plotId] = PlotWaterLog(block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER());
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER());
        }

        // need to initiate surrounding plot water logs due to possible plant placement
        (uint256 plotX, uint256 plotY) = Utils.getCoordinates(plotId, plotMaxX);

        if (plotY > 0 && plotWaterLog[Utils.getUpperPlotId(plotId, plotMaxX)].blockNumber == 0) {
            plotWaterLog[Utils.getUpperPlotId(plotId, plotMaxX)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER()
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER());
        }

        if (plotX < plotMaxX - 1 && plotWaterLog[Utils.getRightPlotId(plotId)].blockNumber == 0) {
            plotWaterLog[Utils.getRightPlotId(plotId)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER()
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER());
        }

        if (plotY < plotMaxY - 1 && plotWaterLog[Utils.getLowerPlotId(plotId, plotMaxX)].blockNumber == 0) {
            plotWaterLog[Utils.getLowerPlotId(plotId, plotMaxX)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER()
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER());
        }

        if (plotX > 0 && plotWaterLog[Utils.getLeftPlotId(plotId)].blockNumber == 0) {
            plotWaterLog[Utils.getLeftPlotId(plotId)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER()
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER());
        }
    }

    function plant(address seed, uint256 plotId) public returns (Plant memory) {
        bool isGrowthSeason = getIsNowSeedGrowthSeason(seed);
        require(isGrowthSeason, "IS_NOT_GROWTH_SEASON");

        Seed(seed).transferFrom(msg.sender, address(this), 1);
        Plot(getPlotAddr()).transferFrom(msg.sender, address(this), plotId);
       
        uint256 plotMaxX = FarmSettings(_farmSettings).PLOT_AREA_MAX_X();

        (uint256 plotX, uint256 plotY) = Utils.getCoordinates(plotId, plotMaxX);

        // update water levels so that harvest math becomes easier (at the expense of gas)
        // plots are always up to date

        // update water absorption of surrounding plots
        if (plotY > 0) {
            updatePlotAndPlantWater(Utils.getUpperPlotId(plotId, plotMaxX), plotMaxX);
        }

        if (plotX < plotMaxX - 1) {
            updatePlotAndPlantWater(Utils.getRightPlotId(plotId), plotMaxX);
        }

        if (plotY < FarmSettings(_farmSettings).PLOT_AREA_MAX_Y() - 1) {
            updatePlotAndPlantWater(Utils.getLowerPlotId(plotId, plotMaxX), plotMaxX);
        }

        if (plotX > 0) {
            updatePlotAndPlantWater(Utils.getLeftPlotId(plotId), plotMaxX);
        }

        // update water absorption of current plot
        updatePlotAndPlantWater(plotId, plotMaxX);

        userPlants[msg.sender].push(plotId);

        Plant memory newPlant = Plant(
            msg.sender,
            seed,
            plotId,
            block.number,
            block.number + (Seed(seed).getGrowthDuration() * 3 / 2), // overgrowth is 1.5x of growthDuration
            0,
            userPlants[msg.sender].length - 1
        );

        plotPlant[plotId] = newPlant;

        return newPlant;
    }

    function getUserPlantIds(address user) public view returns (uint256[] memory) {
        return userPlants[user];
    }

    function getPlantByPlotId(uint256 plotId) public view returns (Plant memory) {
        return plotPlant[plotId];
    }

    function harvest(uint256 plotId) public returns (bool) {
        require(plotPlant[plotId].owner == msg.sender, "NOT_OWNER");
        require(
            block.number - plotPlant[plotId].plantedBlockNumber >= Seed(plotPlant[plotId].seed).getGrowthDuration(),
            "NOT_FINISHED_GROWING"
        );

        uint256 plotMaxX = FarmSettings(_farmSettings).PLOT_AREA_MAX_X();
        (uint256 plotX, uint256 plotY) = Utils.getCoordinates(plotId, plotMaxX);

        if (plotY > 0) {
            updatePlotAndPlantWater(Utils.getUpperPlotId(plotId, plotMaxX), plotMaxX);
        }

        if (plotX < plotMaxX - 1) {
            updatePlotAndPlantWater(Utils.getRightPlotId(plotId), plotMaxX);
        }

        if (plotY < FarmSettings(_farmSettings).PLOT_AREA_MAX_Y() - 1) {
            updatePlotAndPlantWater(Utils.getLowerPlotId(plotId, plotMaxX), plotMaxX);
        }

        if (plotX > 0) {
            updatePlotAndPlantWater(Utils.getLeftPlotId(plotId), plotMaxX);
        }

        updatePlotAndPlantWater(plotId, plotMaxX);

        if (block.number >= plotPlant[plotId].overgrownBlockNumber || !getIsNowSeedGrowthSeason(plotPlant[plotId].seed)) {
            address weedProduct = FarmSettings(_farmSettings).getWeedProduct();

            // TODO: can write a custom mint function to use internal yield value
            Product(weedProduct).mint(msg.sender, Product(weedProduct).getYield());
            
            // cleanup
            delete plotPlant[plotId];
            Plot(getPlotAddr()).transferFrom(address(this), msg.sender, plotId);
            clearUserPlant(plotId);

            emit HarvestOvergrown(plotId);
            return true;
        }

        if (plotPlant[plotId].waterAbsorbed < Seed(plotPlant[plotId].seed).getMinWater()) {
            emit HarvestNotEnoughWater(plotId, plotPlant[plotId].waterAbsorbed);
            return false;
        }

        address product = FarmSettings(_farmSettings).getSeedProduct(plotPlant[plotId].seed);
        Product(product).mint(msg.sender, Product(product).getYield());

        // cleanup
        delete plotPlant[plotId];
        Plot(getPlotAddr()).transferFrom(address(this), msg.sender, plotId);
        clearUserPlant(plotId);

        emit HarvestSuccess(plotId);
        return true;
    }   

    function convertProductsToSeeds(address product, uint256 quantity) public {
        address seed = FarmSettings(_farmSettings).getProductSeed(product);
        if (seed == address(0)) {
            revert("PRODUCT_NOT_CONVERTIBLE_TO_SEED");
        }

        Product(product).transferFrom(msg.sender, address(this), quantity);

        Seed(seed).mint(msg.sender, quantity);
    }

    // product order matters
    function convertProductsToDish(address[] calldata products, uint256[] calldata quantities) public {
        FarmSettings.Recipe memory recipe = FarmSettings(_farmSettings).getRecipe(products, quantities);

        require(recipe.resultDish != address(0), "RECIPE_DOES_NOT_EXIST");

        for (uint i = 0; i < products.length; i++) {
            if (products[i] == address(0)) {
                continue;
            }
            Product(products[i]).transferFrom(msg.sender, address(this), quantities[i]);
        }

        Dish(FarmSettings(_farmSettings).getRecipe(products, quantities).resultDish).mintNext(msg.sender);
    }

    // PRIVATE FUNCTIONS

    function getPlotAddr() private view returns (address) {
        return FarmSettings(_farmSettings).getPlot();
    }

    function getIsNowSeedGrowthSeason(address seed) private view returns (bool) {
        Utils.Season season = Utils.getCurrentSeason(block.number, FarmSettings(_farmSettings).SEASON_DURATION());
        return Utils.getHasGrowthSeason(season, Seed(seed).getGrowthSeasons());
    }

    // returns neighbor neihboring plot total water absorption (up, right, down, left) reversed coordinate axis (smaller x/y is upper left corner)
    function getSurroundingPlantAbsorption(
        uint256 plotId,
        uint256 blocksElapsed,
        uint256 plotMaxX,
        uint256 plotMaxY,
        uint256 plantNeighborWaterAbsorbRate
    ) private view returns (uint256[4] memory) {
        if (blocksElapsed == 0) {
            return [uint256(0), uint256(0), uint256(0), uint256(0)];
        }

        uint256[4] memory surroundingPlantAbsorption = [uint256(0), uint256(0), uint256(0), uint256(0)];
        (uint256 plotX, uint256 plotY) = Utils.getCoordinates(plotId, plotMaxX);

        if (plotY > 0 && plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].owner != address(0)) {
            surroundingPlantAbsorption[0] += plantNeighborWaterAbsorbRate * blocksElapsed;
        }

        if (plotX < plotMaxX - 1 && plotPlant[Utils.getRightPlotId(plotId)].owner != address(0)) {
            surroundingPlantAbsorption[1] += plantNeighborWaterAbsorbRate * blocksElapsed;
        }
        
        if (plotY < plotMaxY - 1 && plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].owner != address(0)) {
            surroundingPlantAbsorption[2] += plantNeighborWaterAbsorbRate * blocksElapsed;
        }

        if (plotX > 0 && plotPlant[Utils.getLeftPlotId(plotId)].owner != address(0)) {
            surroundingPlantAbsorption[3] += plantNeighborWaterAbsorbRate * blocksElapsed;
        }

        return surroundingPlantAbsorption;
    }

    // returns plot plant water absorbed
    function getPlotPlantAbsorption(uint256 plotId, uint256 blocksElapsed) private view returns (uint256) {
        if (plotPlant[plotId].owner == address(0)) {
            return 0;
        }

        return FarmSettings(_farmSettings).PLANT_WATER_ABSORB_RATE() * blocksElapsed;
    }

    // TODO: can be made more gas efficient by not accessing storage so often
    function updatePlotAndPlantWater(uint256 plotId, uint256 plotMaxX) private {
        uint256 blocksElapsed = block.number - plotWaterLog[plotId].blockNumber;

        uint256[4] memory surroundingAbsorbed = getSurroundingPlantAbsorption(
                plotId,
                blocksElapsed,
                plotMaxX,
                FarmSettings(_farmSettings).PLOT_AREA_MAX_Y(),
                FarmSettings(_farmSettings).PLANT_NEIGHBOR_WATER_ABSORB_RATE()
            );
        uint256 mainPlantAbsorbed = getPlotPlantAbsorption(plotId, blocksElapsed);

        uint256 plotWaterLeft = FarmSettings(_farmSettings).PLOT_WATER_REGEN_RATE() * blocksElapsed + plotWaterLog[plotId].level;
        uint256 waterAbsorbed = mainPlantAbsorbed + surroundingAbsorbed[0] + surroundingAbsorbed[1] + surroundingAbsorbed[2] + surroundingAbsorbed[3];

        if (waterAbsorbed > 0) {
            // 100000 multiplier due to solidity not supporting fractions
            uint256 waterRatio = plotWaterLeft * 100000 / waterAbsorbed;

            if (mainPlantAbsorbed > 0) {
                uint256 plantAbsorbed = waterRatio >= 100000 ? mainPlantAbsorbed : waterRatio * mainPlantAbsorbed / 100000;
                plotWaterLeft -= plantAbsorbed;
                plotPlant[plotId].waterAbsorbed += plantAbsorbed;
            }

            if (surroundingAbsorbed[0] > 0) {
                uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingAbsorbed[0] : waterRatio * surroundingAbsorbed[0] / 100000;
                plotWaterLeft -= plantAbsorbed;
                plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].waterAbsorbed += plantAbsorbed;
            }

            if (surroundingAbsorbed[1] > 0) {
                uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingAbsorbed[1] : waterRatio * surroundingAbsorbed[1] / 100000;
                plotWaterLeft -= plantAbsorbed;
                plotPlant[Utils.getRightPlotId(plotId)].waterAbsorbed += plantAbsorbed;
            }

            if (surroundingAbsorbed[2] > 0) {
                uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingAbsorbed[2] : waterRatio * surroundingAbsorbed[2] / 100000;
                plotWaterLeft -= plantAbsorbed;
                plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].waterAbsorbed += plantAbsorbed;
            }

            if (surroundingAbsorbed[3] > 0) {
                uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingAbsorbed[3] : waterRatio * surroundingAbsorbed[3] / 100000;
                plotWaterLeft -= plantAbsorbed;
                plotPlant[Utils.getLeftPlotId(plotId)].waterAbsorbed += plantAbsorbed;
            }

            // due to rounding there might be some leftover water
            if (waterRatio <= 100000 && plotWaterLeft > 0) {
                if (mainPlantAbsorbed > 0) {
                    plotPlant[plotId].waterAbsorbed += 1;
                    plotWaterLeft -= 1;
                }

                if (plotWaterLeft > 0 && surroundingAbsorbed[0] > 0) {
                    plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].waterAbsorbed += 1;
                    plotWaterLeft -= 1;
                }

                if (plotWaterLeft > 0 && surroundingAbsorbed[1] > 0) {
                    plotPlant[Utils.getRightPlotId(plotId)].waterAbsorbed += 1;
                    plotWaterLeft -= 1;
                }

                if (plotWaterLeft > 0 && surroundingAbsorbed[2] > 0) {
                    plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].waterAbsorbed += 1;
                    plotWaterLeft -= 1;
                }

                if (plotWaterLeft > 0 && surroundingAbsorbed[3] > 0) {
                    plotPlant[Utils.getLeftPlotId(plotId)].waterAbsorbed += 1;
                    plotWaterLeft -= 1;
                }
            }
        }

        plotWaterLog[plotId].level = plotWaterLeft > FarmSettings(_farmSettings).PLOT_MAX_WATER() ? FarmSettings(_farmSettings).PLOT_MAX_WATER() : plotWaterLeft;
        plotWaterLog[plotId].blockNumber = block.number;

        emit PlotWaterUpdate(plotId, block.number, plotWaterLog[plotId].level);
    }

    function clearUserPlant(uint256 plotId) private {
        // delete index from userPlants
        if (userPlants[msg.sender].length > 1 && plotPlant[plotId]._userPlantIdIndex + 1 != userPlants[msg.sender].length) {
            // update _userPlantIdIndex inside the plant struct
            plotPlant[userPlants[msg.sender][userPlants[msg.sender].length - 1]]._userPlantIdIndex = plotPlant[plotId]._userPlantIdIndex;
            userPlants[msg.sender][plotPlant[plotId]._userPlantIdIndex] = userPlants[msg.sender][userPlants[msg.sender].length - 1];
            userPlants[msg.sender].pop();
        } else {
            userPlants[msg.sender].pop();
        }
    }

    // APP HELPER FUNCTIONS

    function getPlotView(uint256 leftUpperCornerPlotId) public view returns (PlotView[49] memory) {
        PlotView[49] memory plots;
        uint256 plotMaxX = FarmSettings(_farmSettings).PLOT_AREA_MAX_X();

        (uint256 leftUpperX, uint256 leftUpperY) = Utils.getCoordinates(leftUpperCornerPlotId, plotMaxX);
        for (uint256 dy = 0; dy < 7; dy += 1) {
            for (uint256 dx = 0; dx < 7; dx += 1) {
                uint256 x = leftUpperX + dx;
                uint256 y = leftUpperY + dy;
                uint256 plotId = Utils.getPlotIdFromCoordinates(x, y, plotMaxX);

                address owner = address(0);
                if (Plot(getPlotAddr()).exists(plotId)) {
                    owner = Plot(getPlotAddr()).ownerOf(plotId);
                }

                Plant memory plant_ = getPlantByPlotId(plotId);
                plots[dx + dy * 7] = PlotView(owner, plant_);
            }
         }
        return plots;
    }
}
