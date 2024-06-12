const { expect } = require('chai');

const {
  waitTx,
  approveTokens,
  mintTokens,
  buyApprovePlantPotato,
  expectToFailWithMessage,
} = require('./helpers/utils');

const {
  setupContracts,
} = require('./helpers/setup');

// ******
let contracts;
let account;

describe('Plant', function () {
  this.timeout(150000000);

  async function mintAndApproveTokens(contracts, account) {
    await mintTokens(contracts.stableToken, account, 100);
    await approveTokens(contracts.stableToken, contracts.farm.address, account, 100);
  }

  // *******************
  beforeEach('setup', async function () {
    const options = {};
    contracts = await setupContracts(options);
    [account] = await ethers.getSigners();

    await mintAndApproveTokens(contracts, account);
  });

  describe('Plant seed', async function () {
    it('Should fail plant 1 seed - no seed allowance', async function () {
      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).plant(contracts.potatoSeed.address, 0)
        ),
        `ERC20InsufficientAllowance("${contracts.farm.address}`
      );
    });

    it('Should fail plant 1 seed - no seed balance', async function () {
      await approveTokens(contracts.potatoSeed, contracts.farm.address, account, 1);

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).plant(contracts.potatoSeed.address, 0)
        ),
        `ERC20InsufficientBalance("${account.address}`
      );
    });

    it('Should fail plant 1 seed - plot does not exist', async function () {
      await waitTx(
        contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, 1)
      );
      await approveTokens(contracts.potatoSeed, contracts.farm.address, account, 1);

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).plant(contracts.potatoSeed.address, 0)
        ),
        'ERC721NonexistentToken(0)'
      );
    });

    it('Should fail plant 1 seed - no plot allowance', async function () {
      const plotId = 0;

      await waitTx(
        contracts.farm.connect(account).buyPlot(plotId)
      );
      await waitTx(
        contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, 1)
      );
      await approveTokens(contracts.potatoSeed, contracts.farm.address, account, 1);

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).plant(contracts.potatoSeed.address, plotId)
        ),
        `ERC721InsufficientApproval("${contracts.farm.address}`
      );
    });
    
    it('Should fail plant 1 seed - not growth season', async function () {
      // potatoGrowthSeasons 0 means no growth season
      const options = { potatoGrowthSeasons: 0, seasonDuration: 10 };
      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);
      const plotId = '0';

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).plant(contracts.potatoSeed.address, plotId)
        ),
        'IS_NOT_GROWTH_SEASON'
      );
    });

    it('Plant 1 seed', async function () {
      const plotId = '0';

      await buyApprovePlantPotato(contracts, account, plotId);

      const seedsOwned = await contracts.potatoSeed.balanceOf(account.address);
      expect(seedsOwned.toString()).to.eq('0', 'Seed quantity not matching');

      const plantIds = await contracts.farm.getUserPlantIds(account.address);
      expect(plantIds.length)
        .to.eq(1, 'Didn\'t receive plant id');

      const plant = await contracts.farm.getPlantByPlotId(plantIds[0]);
      expect(plant.plotId.toString()).to.eq(plotId, 'Plant plotId not matching');
      expect(plant.seed).to.eq(contracts.potatoSeed.address, 'Plant seed address not matching');
      expect(plant.owner).to.eq(account.address, 'Plant owner should match planter');
      expect(plant).to.include.all.keys(
        'plantedBlockNumber',
        'overgrownBlockNumber',
        'waterAbsorbed',
        '_userPlantIdIndex',
      );
    });

    it('Plant 1 seed success - updates plotWaterLog and emits PlotWaterUpdate event', async function () {
      const plotId = '0';

      const receipt = await buyApprovePlantPotato(contracts, account, plotId);

      // water log
      const plotWaterLog = await contracts.farm.getWaterLogByPlotId('0');
      expect(plotWaterLog.changeRate.toString()).to.eq('15', 'PlotWaterLog change rate not matching');

      // event
      const events = receipt.events.filter(e => e.event === 'PlotWaterUpdate');

      // 3 events: because plotId 0 has only 2 neighbors
      if (!events || events.length !== 3) { expect.fail('No or not enough PlotWaterUpdate events'); }

      // 3rd event is of the main plot
      const { args } = contracts.farm.interface.parseLog(events[2]);

      expect(args.plotId.toString()).to.eq('0', 'Event plot id not matching');
      expect(args.changeRate.toString()).to.eq('15', 'Event water change rate not matching');
    });

    it('Plant 1 seed success - updates NEIGHBOR plotWaterLog and emits PlotWaterUpdate event', async function () {
      const plotId = '0';

      const receipt = await buyApprovePlantPotato(contracts, account, plotId);

      // water log
      const plotWaterLog = await contracts.farm.getWaterLogByPlotId('1000');
      expect(plotWaterLog.changeRate.toString()).to.eq('4', 'PlotWaterLog change rate not matching');

      // event
      const events = receipt.events.filter(e => e.event === 'PlotWaterUpdate');

      // 3 events: because plotId 0 has only 2 neighbors
      if (!events || events.length !== 3) { expect.fail('No or not enough PlotWaterUpdate events'); }

      // 3rd event is of the main plot
      const { args } = contracts.farm.interface.parseLog(events[0]);

      expect(args.plotId.toString()).to.eq('1000', 'Event plot id not matching');
      expect(args.changeRate.toString()).to.eq('4', 'Event water change rate not matching');
    });

    it('Should fail plant 1 seed - plot already planted', async function () {
      const plotId = 0;

      await buyApprovePlantPotato(contracts, account, plotId);
      await waitTx(
        contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, 1)
      );
      await approveTokens(contracts.potatoSeed, contracts.farm.address, account, 1);

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).plant(contracts.potatoSeed.address, plotId)
        ),
        `ERC721IncorrectOwner("${account.address}`
      );
    });
  });
});
