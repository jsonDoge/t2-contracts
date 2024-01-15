const config = require('./config');

module.exports = {
  ...config,

  POTATO_GROWTH_DURATION: 2,
  POTATO_GROWTH_SEASONS: 15, // all seasons 4 bit wise (1111),
  POTATO_YIELD: 1,
  POTATO_MIN_WATER: 2 * 15,

  WEED_YIELD: 1
};