const { expect } = require('chai');

const {
  setupContracts,
} = require('./helpers/setup');

// ******

let contracts;
let account;

describe('App helper functions', function () {
  this.timeout(150000000);

  // *******************
  beforeEach('setup', async function () {
    const options = {};
    contracts = await setupContracts(options);
    [account] = await ethers.getSigners();
  });

  describe('Plot view', async function () {
    it('Returns 49 plots on view request', async function () {
      const plotId = '0';
      const plots = await contracts.farm.connect(account).getPlotView(plotId);

      expect(plots.length).to.eq(49);
    });
  });
});
