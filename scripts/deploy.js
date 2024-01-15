const {
  PLOT_WATER_REGEN_RATE,
  PLANT_NEIGHBOR_WATER_ABSORB_RATE,
  PLOT_AREA_MAX_X,
  PLOT_AREA_MAX_Y,
  SEASON_DURATION,
  PLOT_MAX_WATER,
  PLANT_WATER_ABSORB_RATE,

  POTATO_GROWTH_DURATION,
  CORN_GROWTH_DURATION,
  CARROT_GROWTH_DURATION,

  POTATO_GROWTH_SEASONS,
  CORN_GROWTH_SEASONS,
  CARROT_GROWTH_SEASONS,

  POTATO_YIELD,
  CORN_YIELD,
  CARROT_YIELD,

  POTATO_MIN_WATER,
  CORN_MIN_WATER,
  CARROT_MIN_WATER,
  WEED_YIELD,
} = require('../config.demo');

// Seed params are made from product like this:
// name: Potato + _seed = Potato_seed
// symbol: PTT + _SEED => PTT_SEED

// Dish params are made from product like this:
// name: Potato + _dish = Potato_dish
// symbol: PTT + _DISH => PTT_DISH

const products = [
  {
    symbol: 'PTT',
    name: 'Potato',
    growthDuration: POTATO_GROWTH_DURATION,
    growthSeasons: POTATO_GROWTH_SEASONS,
    yield: POTATO_YIELD,
    minWater: POTATO_MIN_WATER,
  },
  {
    symbol: 'CRN',
    name: 'Corn',
    growthDuration: CORN_GROWTH_DURATION, // 1 min
    growthSeasons: CORN_GROWTH_SEASONS, // 0101
    yield: CORN_YIELD,
    minWater: CORN_MIN_WATER,
  },
  {
    symbol: 'CRT',
    name: 'Carrot',
    growthDuration: CARROT_GROWTH_DURATION, // 1 min
    growthSeasons: CARROT_GROWTH_SEASONS, // 1010
    yield: CARROT_YIELD,
    minWater: CARROT_MIN_WATER,
  },
];

const deployWithOptions = async (
  contractName,
  factoryOptions = {},
  ...deployArgs
) => {
  const factory = await ethers.getContractFactory(contractName, factoryOptions);
  return deployWithFactory(factory, ...deployArgs);
};

const deployWithFactory = async (factory, ...deployArgs) => {
  const deployment = await factory.deploy(...deployArgs);
  const tx = await deployment.deployTransaction.wait();
  return factory.attach(tx.contractAddress);
};

const deploy = async (contractName, ...deployArgs) =>
  deployWithOptions(contractName, undefined, ...deployArgs);

async function main() {
  const stableToken = await deploy('ERC20Mintable', 'Stable', 'STBL');
  console.info(`C_STABLE_TOKEN=${stableToken.address}`);

  const farmSettings = await deploy(
    'FarmSettings',
    SEASON_DURATION,
    PLOT_WATER_REGEN_RATE,
    PLANT_WATER_ABSORB_RATE,
    PLANT_NEIGHBOR_WATER_ABSORB_RATE,
    PLOT_MAX_WATER,
    PLOT_AREA_MAX_X,
    PLOT_AREA_MAX_Y
  );
  console.info(`C_FARM_SETTINGS=${farmSettings.address}`);

  const utils = await deploy('Utils');

  const farmFactoryOptions = { libraries: { Utils: utils.address } };
  const farm = await deployWithOptions(
    'Farm',
    farmFactoryOptions,
    farmSettings.address,
    stableToken.address
  );
  console.info(`C_FARM=${farm.address}`);

  // plot
  const plot = await deploy('Plot', 'Plot', 'PLT', farm.address, PLOT_AREA_MAX_X * PLOT_AREA_MAX_Y);
  console.info(`C_PLOT=${plot.address}`);

  const SeedFactory = await ethers.getContractFactory('Seed');
  const ProductFactory = await ethers.getContractFactory('Product');

  for (let p of products) {
    // seed
    const seed = await deployWithFactory(
      SeedFactory,
      `${p.name}_seed`,
      `${p.symbol}_SEED`,
      farm.address,
      p.growthDuration,
      p.growthSeasons,
      p.minWater
    );
    console.info(`C_${p.name.toUpperCase()}_SEED=${seed.address}`);

    // product
    const product = await deployWithFactory(
      ProductFactory,
      p.name,
      p.symbol,
      farm.address,
      p.yield
    );
    console.info(`C_${p.name.toUpperCase()}_PRODUCT=${product.address}`);

    // dish
    const dish = await deploy(
      'Dish',
      `${p.name}_dish`,
      `${p.symbol}_DISH`,
      farm.address
    );
    console.info(`C_${p.name.toUpperCase()}_DISH=${dish.address}`);

    // add seed|product|dish to settings
    await farmSettings.mapSeedAndProduct(seed.address, product.address);
    await farmSettings.setRecipe([product.address], [3], dish.address);
  }

  // weeds do not have a dedicated seed

  const weed = await deployWithFactory(
    ProductFactory,
    'Weed',
    'WED',
    farm.address,
    WEED_YIELD
  );
  console.info(`C_WEED_PRODUCT=${weed.address}`);

  const weedDish = await deploy(
    'Dish',
    'Weed_dish',
    'WED_DISH',
    farm.address
  );
  console.info(`C_WEED_DISH=${weedDish.address}`);
  await farmSettings.setRecipe([weed.address], [3], weedDish.address);

  // TODO: review deploying order (gaps where necessary contracts are missing, but farm deployed)
  await farmSettings.setPlot(plot.address);
  await farmSettings.setWeedProduct(weed.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
