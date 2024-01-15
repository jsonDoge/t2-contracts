module.exports = {
  PLOT_AREA_MAX_X: 1000, // in code max value is not reached due to starting at 0
  PLOT_AREA_MAX_Y: 1000,

  // block = 2s
  SEASON_DURATION: 604800, // blocks    (around 2 weeks)

  PLOT_WATER_REGEN_RATE: 10, // per block

  // currently all plant absorb rate is the same
  PLANT_WATER_ABSORB_RATE: 15, // per block
  PLANT_NEIGHBOR_WATER_ABSORB_RATE: 4, // per block

  PLOT_MAX_WATER: 100000, // max water value in plot
};