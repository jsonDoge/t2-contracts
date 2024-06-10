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
        uint256 changeRate; // storing last change rate for easier calculations - can be removed if front-end moves to event using
    }

    struct PlotView {
        address owner;
        Plant plant;
        PlotWaterLog waterLog;
    }

    address private _farmSettings;
    address private _acceptedToken;

    mapping(uint256 => Plant) private plotPlant;
    mapping(uint256 => PlotWaterLog) private plotWaterLog;
    mapping(address => uint256[]) private userPlants;

    event HarvestNotEnoughWater(uint256 plotId, uint256 waterAbsorbed);
    event HarvestOvergrown(uint256 plotId);
    event HarvestSuccess(uint256 plotId);
    event PlotWaterUpdate(uint256 plotId, uint256 blockNumber, uint256 level, uint256 changeRate);

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
        // if plot water log is not initiated, initiate it (plot gets MAX water if no surrounding plots are planted)
        if (plotWaterLog[plotId].blockNumber == 0) {
            plotWaterLog[plotId] = PlotWaterLog(block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER(), 0);
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER(), 0);
        }

        // need to initiate surrounding plot water logs due to possible plant placement
        (uint256 plotX, uint256 plotY) = Utils.getCoordinates(plotId, plotMaxX);

        if (plotY > 0 && plotWaterLog[Utils.getUpperPlotId(plotId, plotMaxX)].blockNumber == 0) {
            plotWaterLog[Utils.getUpperPlotId(plotId, plotMaxX)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER(),
                0
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER(), 0);
        }

        if (plotX < plotMaxX - 1 && plotWaterLog[Utils.getRightPlotId(plotId)].blockNumber == 0) {
            plotWaterLog[Utils.getRightPlotId(plotId)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER(),
                0
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER(), 0);
        }

        if (plotY < plotMaxY - 1 && plotWaterLog[Utils.getLowerPlotId(plotId, plotMaxX)].blockNumber == 0) {
            plotWaterLog[Utils.getLowerPlotId(plotId, plotMaxX)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER(),
                0
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER(), 0);
        }

        if (plotX > 0 && plotWaterLog[Utils.getLeftPlotId(plotId)].blockNumber == 0) {
            plotWaterLog[Utils.getLeftPlotId(plotId)] = PlotWaterLog(
                block.number,
                FarmSettings(_farmSettings).PLOT_MAX_WATER(),
                0
            );
            emit PlotWaterUpdate(plotId, block.number, FarmSettings(_farmSettings).PLOT_MAX_WATER(), 0);
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
    
    function getWaterLogByPlotId(uint256 plotId) public view returns (PlotWaterLog memory) {
        return plotWaterLog[plotId];
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

    // returns neighbor neihboring plot total water absorption (up, right, down, left) reversed coordinate Y axis (smaller x/y is upper left corner)
    function getSurroundingPlantAbsorbRates(
        uint256 plotId,
        uint256 plotMaxX,
        uint256 plotMaxY,
        // TODO later this can vary for different plants
        uint256 plantNeighborWaterAbsorbRate
    ) private view returns (uint256[4] memory) {
        if (blocksElapsed == 0) {
            return [uint256(0), uint256(0), uint256(0), uint256(0)];
        }

        uint256[4] memory surroundingPlantAbsorbRates = [uint256(0), uint256(0), uint256(0), uint256(0)];
        (uint256 plotX, uint256 plotY) = Utils.getCoordinates(plotId, plotMaxX);

        if (plotY > 0 && plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].owner != address(0)) {
            surroundingPlantAbsorbRates[0] += plantNeighborWaterAbsorbRate;
        }

        if (plotX < plotMaxX - 1 && plotPlant[Utils.getRightPlotId(plotId)].owner != address(0)) {
            surroundingPlantAbsorbRates[1] += plantNeighborWaterAbsorbRate;
        }
        
        if (plotY < plotMaxY - 1 && plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].owner != address(0)) {
            surroundingPlantAbsorbRates[2] += plantNeighborWaterAbsorbRate;
        }

        if (plotX > 0 && plotPlant[Utils.getLeftPlotId(plotId)].owner != address(0)) {
            surroundingPlantAbsorbRates[3] += plantNeighborWaterAbsorbRate;
        }

        return surroundingPlantAbsorbRates;
    }

    function getPlotWaterChangeRate(uint256 plotId, uint256 plotMaxX, uint256 plotMaxY, uint256 plantNeighborWaterAbsorbRate, uint256 mainPlantWaterAbsorbRate) private view returns (uint256) {
        uint256 changeRate = 0;

        if (plotPlant[plotId].owner != address(0)) {
            changeRate += mainPlantWaterAbsorbRate;
        }

        (uint256 plotX, uint256 plotY) = Utils.getCoordinates(plotId, plotMaxX);

        if (plotY > 0 && plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].owner != address(0)) {
            changeRate += plantNeighborWaterAbsorbRate;
        }

        if (plotX < plotMaxX - 1 && plotPlant[Utils.getRightPlotId(plotId)].owner != address(0)) {
            changeRate += plantNeighborWaterAbsorbRate;
        }
        
        if (plotY < plotMaxY - 1 && plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].owner != address(0)) {
            changeRate += plantNeighborWaterAbsorbRate;
        }

        if (plotX > 0 && plotPlant[Utils.getLeftPlotId(plotId)].owner != address(0)) {
            changeRate += plantNeighborWaterAbsorbRate;
        }

        return changeRate;
    }

    // returns plot plant water absorbed
    function getPlotPlantAbsorption(uint256 plotId, uint256 blocksElapsed, uint256 absorbRate) private view returns (uint256) {
        if (plotPlant[plotId].owner == address(0)) {
            return 0;
        }

        return absorbRate * blocksElapsed;
    }

    // updated plot plant and surrounding plant water absrobed
    // returns plot water left after absorption and current total absorb rate
    function updatePlantWater(uint256 plotId, uint256 plotMaxX, uint256 mainPlantAbsorbRate, uint256[4] memory surroundingPlantsAbsorbRates, uint256 plotWaterLeft, uint256 blocksElapsed) private returns (uint256, uint256) {
        uint256 totalAbsorbRate = mainPlantAbsorbRate + surroundingPlantsAbsorbRates[0] + surroundingPlantsAbsorbRates[1] + surroundingPlantsAbsorbRates[2] + surroundingPlantsAbsorbRates[3];

        uint256 totalAbsorption = totalAbsorbRate * blocksElapsed;

        if (waterAbsorbed > 0) {
            uint256 availableWaterBlocks = plotWaterLeft / totalAbsorbRate;
            uint256 waterBlocksAbsorbed = fullWaterBlocks >= blocksElapsed ? blocksElapsed : fullWaterBlocks;


            plotPlant[plotId].waterAbsorbed += waterBlocksAbsorbed * mainPlantAbsorbRate;

            if (surroundingPlantsAbsorbed[0] > 0) {
                plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].waterAbsorbed += waterBlocksAbsorbed * surroundingPlantsAbsorbRates[0];
            }

            if (surroundingPlantsAbsorbed[1] > 0) {
                plotPlant[Utils.getRightPlotId(plotId)].waterAbsorbed += waterBlocksAbsorbed * surroundingPlantsAbsorbRates[1];
            }

            if (surroundingPlantsAbsorbed[2] > 0) {
                plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].waterAbsorbed += waterBlocksAbsorbed * surroundingPlantsAbsorbRates[2];
            }

            if (surroundingPlantsAbsorbed[3] > 0) {
                plotPlant[Utils.getLeftPlotId(plotId)].waterAbsorbed += waterBlocksAbsorbed * surroundingPlantsAbsorbRates[3];
            }

            plotWaterLeft -= totalAbsorbRate * waterBlocksAbsorbed;
        }

        // Old method used with partial absorption calculation
        // if (waterAbsorbed > 0) {
        //     // 100000 multiplier due to solidity not supporting fractions
        //     uint256 waterRatio = plotWaterLeft * 100000 / waterAbsorbed;

        //     if (mainPlantAbsorbed > 0) {
        //         uint256 plantAbsorbed = waterRatio >= 100000 ? mainPlantAbsorbed : waterRatio * mainPlantAbsorbed / 100000;
        //         plotWaterLeft -= plantAbsorbed;
        //         plotPlant[plotId].waterAbsorbed += plantAbsorbed;
        //     }

        //     if (surroundingPlantsAbsorbed[0] > 0) {
        //         uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingPlantsAbsorbed[0] : waterRatio * surroundingPlantsAbsorbed[0] / 100000;
        //         plotWaterLeft -= plantAbsorbed;
        //         plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].waterAbsorbed += plantAbsorbed;
        //     }

        //     if (surroundingPlantsAbsorbed[1] > 0) {
        //         uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingPlantsAbsorbed[1] : waterRatio * surroundingPlantsAbsorbed[1] / 100000;
        //         plotWaterLeft -= plantAbsorbed;
        //         plotPlant[Utils.getRightPlotId(plotId)].waterAbsorbed += plantAbsorbed;
        //     }

        //     if (surroundingPlantsAbsorbed[2] > 0) {
        //         uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingPlantsAbsorbed[2] : waterRatio * surroundingPlantsAbsorbed[2] / 100000;
        //         plotWaterLeft -= plantAbsorbed;
        //         plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].waterAbsorbed += plantAbsorbed;
        //     }

        //     if (surroundingPlantsAbsorbed[3] > 0) {
        //         uint256 plantAbsorbed = waterRatio >= 100000 ? surroundingPlantsAbsorbed[3] : waterRatio * surroundingPlantsAbsorbed[3] / 100000;
        //         plotWaterLeft -= plantAbsorbed;
        //         plotPlant[Utils.getLeftPlotId(plotId)].waterAbsorbed += plantAbsorbed;
        //     }

        //     // due to rounding there might be some leftover water
        //     if (waterRatio <= 100000 && plotWaterLeft > 0) {
        //         if (mainPlantAbsorbed > 0) {
        //             plotPlant[plotId].waterAbsorbed += 1;
        //             plotWaterLeft -= 1;
        //         }

        //         if (plotWaterLeft > 0 && surroundingPlantsAbsorbed[0] > 0) {
        //             plotPlant[Utils.getUpperPlotId(plotId, plotMaxX)].waterAbsorbed += 1;
        //             plotWaterLeft -= 1;
        //         }

        //         if (plotWaterLeft > 0 && surroundingPlantsAbsorbed[1] > 0) {
        //             plotPlant[Utils.getRightPlotId(plotId)].waterAbsorbed += 1;
        //             plotWaterLeft -= 1;
        //         }

        //         if (plotWaterLeft > 0 && surroundingPlantsAbsorbed[2] > 0) {
        //             plotPlant[Utils.getLowerPlotId(plotId, plotMaxX)].waterAbsorbed += 1;
        //             plotWaterLeft -= 1;
        //         }

        //         if (plotWaterLeft > 0 && surroundingPlantsAbsorbed[3] > 0) {
        //             plotPlant[Utils.getLeftPlotId(plotId)].waterAbsorbed += 1;
        //             plotWaterLeft -= 1;
        //         }
        //     }
        // }

        return [plotWaterLeft, totalAbsorbRate];
    }

    // TODO: can be made more gas efficient by not accessing storage so often
    function updatePlotAndPlantWater(uint256 plotId, uint256 plotMaxX) private {
        uint256 blocksElapsed = block.number - plotWaterLog[plotId].blockNumber;

        uint256 neighborWaterAbsorbRate = FarmSettings(_farmSettings).PLANT_NEIGHBOR_WATER_ABSORB_RATE();
        uint256 plotMaxY = FarmSettings(_farmSettings).PLOT_AREA_MAX_Y();

        uint256[4] memory surroundingPlantsAbsorbRates = getSurroundingPlantAbsorbRates(
                plotId,
                plotMaxX,
                plotMaxY,
                neighborWaterAbsorbRate
            );

        uint256 mainPlantWaterAbsorbRate = FarmSettings(_farmSettings).PLANT_WATER_ABSORB_RATE();

        uint256 plotTotalWater = FarmSettings(_farmSettings).PLOT_WATER_REGEN_RATE() * blocksElapsed + plotWaterLog[plotId].level;
        // uint256 mainPlantAbsorbed = getPlotPlantAbsorption(plotId, blocksElapsed, mainPlantWaterAbsorbRate);

        uint256 [plotWaterLeft, changeRate] = updatePlantWater(plotId, plotMaxX, mainPlantWaterAbsorbRate, surroundingPlantsAbsorbRates, plotTotalWater, blocksElapsed);

        uint256 waterChangeRate = getPlotWaterChangeRate(
            plotId,
            plotMaxX,
            plotMaxY,
            neighborWaterAbsorbRate,
            mainPlantWaterAbsorbRate
        );

        plotWaterLog[plotId].level = plotWaterLeft > FarmSettings(_farmSettings).PLOT_MAX_WATER() ? FarmSettings(_farmSettings).PLOT_MAX_WATER() : plotWaterLeft;
        plotWaterLog[plotId].blockNumber = block.number;
        plotWaterLog[plotId].changeRate = waterChangeRate;

        emit PlotWaterUpdate(plotId, block.number, plotWaterLog[plotId].level, waterChangeRate);
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

    // 49 plots in a 7x7 grid
    // left lower corrner is named after app view - basicall left corner (or left lower if rotated) 
    function getPlotView(uint256 leftLowerCornerPlotId) public view returns (PlotView[49] memory) {
        PlotView[49] memory plots;
        uint256 plotMaxX = FarmSettings(_farmSettings).PLOT_AREA_MAX_X();

        (uint256 leftLowerX, uint256 leftLowerY) = Utils.getCoordinates(leftLowerCornerPlotId, plotMaxX);
        for (uint256 dy = 0; dy < 7; dy += 1) {
            for (uint256 dx = 0; dx < 7; dx += 1) {
                uint256 x = leftLowerX + dx;
                uint256 y = leftLowerY + dy;
                uint256 plotId = Utils.getPlotIdFromCoordinates(x, y, plotMaxX);

                address owner = address(0);
                if (Plot(getPlotAddr()).exists(plotId)) {
                    owner = Plot(getPlotAddr()).ownerOf(plotId);
                }

                Plant memory plant_ = getPlantByPlotId(plotId);
                PlotWaterLog memory waterLog_ = getWaterLogByPlotId(plotId);
                plots[dx + dy * 7] = PlotView(owner, plant_, waterLog_);
            }
         }
        return plots;
    }

    // Used for plant water consumption calculation in front-end if the plant is on the edge of the viewable main plot

    // argument is same as getPlotView the leftUpperCorner of 7x7
    // returnes 0-6 - 7 plots along Y line before main plots
    // returnes 7-13 - 7 plots along Y line after main plots
    // returnes 14-20 - 7 plots along X line before main plots
    // returnes 21-27 - 7 plots along X line after main plots

    function getSurroundingWaterLogs(uint256 leftLowerCornerPlotId) public view returns (PlotWaterLog[28] memory) {
        PlotWaterLog[28] memory plotWaterLogs;
        uint256 plotMaxX = FarmSettings(_farmSettings).PLOT_AREA_MAX_X();

        (uint256 leftLowerX, uint256 leftLowerY) = Utils.getCoordinates(leftLowerCornerPlotId, plotMaxX);

        if (leftLowerX > 0) {
            // Y axis parrallel before
            for (uint256 dy = 0; dy < 7; dy += 1) {
                uint256 plotId = Utils.getPlotIdFromCoordinates(leftLowerX - 1, leftLowerY + dy, plotMaxX);
        
                plotWaterLogs[dy] = getWaterLogByPlotId(plotId);
            }
        }

        if (leftLowerX < plotMaxX) {
            // Y axis parrallel after
            for (uint256 dy = 0; dy < 7; dy += 1) {
                uint256 plotId = Utils.getPlotIdFromCoordinates(leftLowerX + 1, leftLowerY + dy, plotMaxX);
        
                // next line + 6
                plotWaterLogs[dy + 6] = getWaterLogByPlotId(plotId);
            }
        }


        if (leftLowerY > 0) {
            // X axis parrallel before
            for (uint256 dx = 0; dx < 7; dx += 1) {
                uint256 plotId = Utils.getPlotIdFromCoordinates(leftLowerX + dx , leftLowerY - 1, plotMaxX);
        
                // next line + 6
                plotWaterLogs[dx + 13] = getWaterLogByPlotId(plotId);
            }
        }

        if (leftLowerY <  FarmSettings(_farmSettings).PLOT_AREA_MAX_Y()) {
            // X axis parrallel after
            for (uint256 dx = 0; dx < 7; dx += 1) {
                uint256 plotId = Utils.getPlotIdFromCoordinates(leftLowerX + dx , leftLowerY + 1, plotMaxX);
        
                // next line + 6
                plotWaterLogs[dx + 20] = getWaterLogByPlotId(plotId);
            }
        }

        return plotWaterLogs;
    }
}
