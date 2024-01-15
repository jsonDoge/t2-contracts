const config = require('./config');

module.exports = {
  ...config,

  // block = 10s
  POTATO_GROWTH_DURATION: 300,
  CORN_GROWTH_DURATION: 150,
  CARROT_GROWTH_DURATION: 100,

  POTATO_GROWTH_SEASONS: 15, // all seasons 4 bit wise (1111),
  CORN_GROWTH_SEASONS: 5, // 0101  - winter and summer
  CARROT_GROWTH_SEASONS: 10, // 1010 - spring and autumn

  POTATO_YIELD: 6,
  CORN_YIELD: 3,
  CARROT_YIELD: 2,
  WEED_YIELD: 1,

  POTATO_MIN_WATER: 300 * 15, // season duration * absorb rate
  CORN_MIN_WATER: 300 * 15 * 2,
  CARROT_MIN_WATER: 300 * 15 * 2,

  SEASON_DURATION: 300, // blocks      (around 50 mins)

  PLOT_WATER_REGEN_RATE: 10, // per block

  PLOT_MAX_WATER: 100000, // max water value in plot
};