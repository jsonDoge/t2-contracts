const {
  PLOT_AREA_MAX_X,
  PLOT_AREA_MAX_Y,
  SEASON_DURATION,
  PLOT_WATER_REGEN_RATE,
  PLANT_WATER_ABSORB_RATE,
  PLANT_NEIGHBOR_WATER_ABSORB_RATE,
  PLOT_MAX_WATER,
  POTATO_GROWTH_DURATION,
  POTATO_GROWTH_SEASONS,
  POTATO_MIN_WATER,
  POTATO_YIELD,
  WEED_YIELD
} = require('../../config.test');

const setupContracts = async ({
  plotAreaMaxX = PLOT_AREA_MAX_X,
  plotAreaMaxY = PLOT_AREA_MAX_Y,
  potatoGrowthDuration = POTATO_GROWTH_DURATION,
  seasonDuration = SEASON_DURATION,
  potatoGrowthSeasons = POTATO_GROWTH_SEASONS,
  plotWaterRegenRate = PLOT_WATER_REGEN_RATE,
  plantWaterAbsorbRate = PLANT_WATER_ABSORB_RATE,
  plantNeighborWaterAbsorbRate = PLANT_NEIGHBOR_WATER_ABSORB_RATE,
  plotMaxWater = PLOT_MAX_WATER,
  potatoMinWater = POTATO_MIN_WATER,
  potatoYield = POTATO_YIELD,
  weedYield = WEED_YIELD,
}) => {
  const ERC20 = await ethers.getContractFactory('ERC20Mintable');
  const stableToken = await ERC20.deploy('Stable', 'STBL');
  await stableToken.deployTransaction.wait();

  const FarmSettings = await ethers.getContractFactory('FarmSettings');
  const farmSettings = await FarmSettings.deploy(
    seasonDuration,
    plotWaterRegenRate,
    plantWaterAbsorbRate,
    plantNeighborWaterAbsorbRate,
    plotMaxWater,
    plotAreaMaxX,
    plotAreaMaxY
  );
  await farmSettings.deployTransaction.wait();

  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployTransaction.wait();

  const Farm = await ethers.getContractFactory('Farm', {
    libraries: {
      Utils: utils.address
    }
  });

  const farm = await Farm.deploy(farmSettings.address, stableToken.address);
  await farm.deployTransaction.wait();

  // plots
  const Plot = await ethers.getContractFactory('Plot');
  const plot = await Plot.deploy('Plot', 'PLT', farm.address, plotAreaMaxX * plotAreaMaxY);
  await plot.deployTransaction.wait();

  const Seed = await ethers.getContractFactory('Seed');
  
  // seeds
  const potatoSeed = await Seed.deploy(
    'Potato_seed',
    'PTT_S',
    farm.address,
    potatoGrowthDuration,
    potatoGrowthSeasons,
    potatoMinWater
  );
  await potatoSeed.deployTransaction.wait();

  const Product = await ethers.getContractFactory('Product');

  // products
  const potatoProduct = await Product.deploy('Potato', 'PTT', farm.address, potatoYield);
  await potatoProduct.deployTransaction.wait();

  const weedProduct = await Product.deploy('Weed', 'WED', farm.address, weedYield);
  await weedProduct.deployTransaction.wait();

  // dishes
  const Dish = await ethers.getContractFactory('Dish');
  const potatoDish = await Dish.deploy('Potato_dish', 'PTT_DISH', farm.address);
  await potatoDish.deployTransaction.wait();

  // add seed|product|dish to map
  await farmSettings.mapSeedAndProduct(potatoSeed.address, potatoProduct.address);
  await farmSettings.setPlot(plot.address);
  await farmSettings.setWeedProduct(weedProduct.address);
  await farmSettings.setRecipe(
    [potatoProduct.address], [3], potatoDish.address
  );

  return {
    farm,
    potatoSeed,
    plot,
    potatoDish,
    potatoProduct,
    weedProduct,
    farmSettings,
    stableToken
  };
};

module.exports = {
  setupContracts,
};