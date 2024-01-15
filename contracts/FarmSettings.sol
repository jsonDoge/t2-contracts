//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev For storing seed to product map
 */
contract FarmSettings {
    uint256 public immutable SEASON_DURATION;
    uint256 public immutable PLOT_WATER_REGEN_RATE;
    uint256 public immutable PLANT_WATER_ABSORB_RATE;
    uint256 public immutable PLANT_NEIGHBOR_WATER_ABSORB_RATE;
    uint256 public immutable PLOT_MAX_WATER;
    uint256 public immutable PLOT_AREA_MAX_X;
    uint256 public immutable PLOT_AREA_MAX_Y;
    // this is simply the deployer
    address private immutable _admin;
    
    struct Recipe {
        // order matters
        address[] products;
        uint256[] quantities;
        address resultDish;
    }

    mapping(bytes32 => Recipe) private _recipes;

    mapping(address => address) private _seedProduct;
    mapping(address => address) private _productSeed;
    address private _plot;
    address private _weedProduct;

    constructor(
        uint256 seasonDuration,
        uint256 plotWaterRegenRate,
        uint256 plantWaterAbsorbRate,
        uint256 plantNeighborWaterAbsorbRate,
        uint256 plotMaxWater,
        uint256 plotAreaMaxX,
        uint256 plotAreaMaxY
    ) {
        _admin = msg.sender;
        SEASON_DURATION = seasonDuration;
        PLOT_WATER_REGEN_RATE = plotWaterRegenRate;
        PLANT_WATER_ABSORB_RATE = plantWaterAbsorbRate;
        PLANT_NEIGHBOR_WATER_ABSORB_RATE = plantNeighborWaterAbsorbRate;
        PLOT_MAX_WATER = plotMaxWater;
        PLOT_AREA_MAX_X = plotAreaMaxX;
        PLOT_AREA_MAX_Y = plotAreaMaxY;
    }

    modifier onlyAdmin() {
        require(_admin == msg.sender, "ONLY_ADMIN");
        _;
    }

    // SEEDS

    function mapSeedAndProduct(address seed, address product) public onlyAdmin {
        require(_seedProduct[seed] == address(0) && _productSeed[product] == address(0), "PRODUCT_ALREADY_SET");
        _seedProduct[seed] = product;
        _productSeed[product] = seed;
    }

    function isValidSeed(address seed) public view returns (bool) {
        return _seedProduct[seed] != address(0);
    }

    function isValidProduct(address product) public view returns (bool) {
        return _productSeed[product] != address(0);
    }

    function getSeedProduct(address seed) public view returns (address) {
        return _seedProduct[seed];
    }

    function getProductSeed(address product) public view returns (address) {
        return _productSeed[product];
    }

    function getWeedProduct() public view returns (address) {
        return _weedProduct;
    }

    function setWeedProduct(address weedProduct) public onlyAdmin {
        require(_weedProduct == address(0), "WEED_ALREADY_SET");
        _weedProduct = weedProduct;
    }

    // PLOTS

    function setPlot(address plot) public onlyAdmin {
        require(_plot == address(0), "PLOT_ALREADY_SET");
        _plot = plot;
    }

    function getPlot() public view returns (address) {
        return _plot;
    }

    // RECIPES

    function setRecipe(address[] calldata products, uint256[] calldata quantities, address resultDish) public onlyAdmin {
        if (products.length != quantities.length) {
            revert("PRODUCTS_QUANTITIES_LENGTH_MISMATCH");
        }

        _recipes[keccak256(abi.encodePacked(products, quantities))] = Recipe(products, quantities, resultDish);
    }

    function unsetRecipe(address[] calldata products, uint256[] calldata quantities) public onlyAdmin {
        delete _recipes[keccak256(abi.encodePacked(products, quantities))];
    }

    function getRecipe(address[] calldata products, uint256[] calldata quantities) public view returns (Recipe memory) {
        return _recipes[keccak256(abi.encodePacked(products, quantities))];
    }
}
