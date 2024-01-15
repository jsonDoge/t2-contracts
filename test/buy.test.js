const { expect } = require('chai');

const {
  waitTx,
  approveTokens,
  mintTokens,
  expectToFailWithMessage,
} = require('./helpers/utils');

const {
  setupContracts,
} = require('./helpers/setup');
const { PLOT_AREA_MAX_X, PLOT_AREA_MAX_Y } = require('../config.test');

const { AddressZero } = ethers.constants;

// ******
let contracts;
let account;

describe('Buy', function () {
  this.timeout(150000000);

  // *******************
  beforeEach('setup', async function () {
    const options = {};
    contracts = await setupContracts(options);
    [account] = await ethers.getSigners();

    await mintTokens(contracts.stableToken, account, 100);
  });

  describe('Seeds', async function () {
    it('Should fail buy 0 seeds', async function () {
      const seedsToBuy = 0;
      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, seedsToBuy)
        ),
        'QUANTITY_MUST_BE_GREATER_THAN_ZERO'
      );
    });

    it('Should fail buy 1 seed - no allowance', async function () {
      const seedsToBuy = 1;
      
      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, seedsToBuy)
        ),
        'ERC20InsufficientAllowance'
      );
    });

    it('Should fail buy 2 seed - not enough allowance', async function () {
      const seedsToBuy = 2;
      
      await approveTokens(contracts.stableToken, contracts.farm.address, account, seedsToBuy - 1);
      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, seedsToBuy)
        ),
        'ERC20InsufficientAllowance'
      );
    });

    it('Should fail buy 1 seed - wrong contract address', async function () {
      const seedsToBuy = 1;
      
      await approveTokens(contracts.stableToken, contracts.farm.address, account, seedsToBuy);
      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).buySeeds(AddressZero, seedsToBuy)
        ),
        'INVALID_SEED'
      );
    });

    it('Buy 1 seed', async function () {
      const seedsToBuy = '1';

      await approveTokens(contracts.stableToken, contracts.farm.address, account, seedsToBuy);
      await waitTx(
        contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, seedsToBuy)
      );

      const seedsReceivedByUser = await contracts.potatoSeed.balanceOf(account.address);
      expect(seedsReceivedByUser.toString())
        .to.eq(seedsToBuy, 'Didn\'t received expected seeds');

      const tokensReceivedByFarm = await contracts.stableToken.balanceOf(contracts.farm.address);
      expect(tokensReceivedByFarm.toString())
        .to.eq(seedsToBuy, 'Farm didn\'t receive expected tokens');
    });

    it('Buy 2 seeds', async function () {
      const seedsToBuy = '2';

      await approveTokens(contracts.stableToken, contracts.farm.address, account, seedsToBuy);
      await waitTx(
        contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, seedsToBuy)
      );
  
      const seedsReceivedByUser = await contracts.potatoSeed.balanceOf(account.address);
      expect(seedsReceivedByUser.toString())
        .to.eq(seedsToBuy, 'Didn\'t received expected seeds');
  
      const tokensReceivedByFarm = await contracts.stableToken.balanceOf(contracts.farm.address);
      expect(tokensReceivedByFarm.toString())
        .to.eq(seedsToBuy, 'Farm didn\'t receive expected tokens');
    });
  });

  describe('Plot', async function () {
    // Plots are indexed from 0 to (plot cap) - 1
    it('Should fail buy 1 plot - above plotId cap', async function () {
      const plotId = (PLOT_AREA_MAX_X * PLOT_AREA_MAX_Y) + 1;

      await approveTokens(contracts.stableToken, contracts.farm.address, account, 1);
      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).buyPlot(plotId)
        ),
        'PLOT_INVALID_ID'
      );
    });

    it('Should fail buy 1 plot - no allowance ', async function () {
      const plotId = '0';

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).buyPlot(plotId)
        ),
        'ERC20InsufficientAllowance'
      );
    });

    it('Buy 1 plot', async function () {
      const plotId = '0';

      await approveTokens(contracts.stableToken, contracts.farm.address, account, 1);
      await waitTx(
        contracts.farm.connect(account).buyPlot(plotId)
      );

      const plotsReceivedByUser = await contracts.plot.balanceOf(account.address);
      expect(plotsReceivedByUser.toString())
        .to.eq('1', 'Didn\'t received expected plots');

      const tokensReceivedByFarm = await contracts.stableToken.balanceOf(contracts.farm.address);
      expect(tokensReceivedByFarm.toString())
        .to.eq('1', 'Farm didn\'t receive expected tokens');
    });

    it('Should fail buy 1 plot - already bought', async function () {
      const plotId = '0';

      await approveTokens(contracts.stableToken, contracts.farm.address, account, 1);
      await waitTx(
        contracts.farm.connect(account).buyPlot(plotId)
      );

      await approveTokens(contracts.stableToken, contracts.farm.address, account, 1);
      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).buyPlot(plotId)
        ),
        'PLOT_ALREADY_MINTED'
      );
    });
  });
});
