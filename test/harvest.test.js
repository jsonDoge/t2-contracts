const { expect } = require('chai');

const {
  waitTx,
  approveTokens,
  approveERC721Tokens,
  mintTokens,
  buyApprovePlantPotato,
  expectToFailWithMessage,
} = require('./helpers/utils');
const helpers = require('@nomicfoundation/hardhat-network-helpers');

const { setupContracts } = require('./helpers/setup');

// ******
let contracts;
let account;

describe('Harvest', function () {
  this.timeout(150000000);

  async function mintAndApproveTokens(contracts, account) {
    await mintTokens(contracts.stableToken, account, 100);
    await approveTokens(
      contracts.stableToken,
      contracts.farm.address,
      account,
      100
    );
  }

  // *******************
  beforeEach('setup', async function () {
    const options = {};
    contracts = await setupContracts(options);
    [account] = await ethers.getSigners();

    await mintAndApproveTokens(contracts, account);
  });

  // will only work if GROWTH_DURATION IS DISABLED
  describe('Harvest plot', async function () {
    it('Should fail harvest plot - not plant owner', async function () {
      const plotId = 0;
      const [, account2] = await ethers.getSigners();

      await buyApprovePlantPotato(contracts, account, plotId);

      await expectToFailWithMessage(
        contracts.farm.connect(account2).harvest(plotId),
        'NOT_OWNER'
      );
    });

    it('Should fail harvest plot - not finished growing immediate harvest', async function () {
      const options = {
        potatoGrowthDuration: 1000,
      };

      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);

      const plotId = 0;

      await buyApprovePlantPotato(contracts, account, plotId);
      await expectToFailWithMessage(
        contracts.farm.connect(account).harvest(plotId),
        'NOT_FINISHED_GROWING'
      );
    });

    it('Should fail harvest plot - not finished growing last block before grown', async function () {
      const options = {
        potatoGrowthDuration: 1000,
      };

      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);

      const plotId = '0';

      await buyApprovePlantPotato(contracts, account, plotId);
      
      // -2 because the harvest function will be called in the block after it
      await helpers.mine(options.potatoGrowthDuration - 2);


      await expectToFailWithMessage(
        contracts.farm.connect(account).harvest(plotId),
        'NOT_FINISHED_GROWING'
      );
    });

    it('Harvest plot - overgrown received weed', async function () {
      const plotId = '0';

      await buyApprovePlantPotato(contracts, account, plotId);

      const plant = await contracts.farm.getPlantByPlotId(plotId);

      const latestBlock = await helpers.time.latestBlock();
      const blocksTillOvergrown = plant.overgrownBlockNumber - latestBlock;

      // HARVEST
      await helpers.mine(blocksTillOvergrown - 1);
      const receipt = await waitTx(contracts.farm.connect(account).harvest(plotId));
      const event = receipt.events.filter(e => e.event === 'HarvestOvergrown')[0];

      if (!event) { expect.fail('No HarvestOvergrown event'); }

      const userPlantIds = await contracts.farm.getUserPlantIds(account.address);
      expect(userPlantIds.length).to.eq(0, 'Plant still exists');

      const plotsOwned = await contracts.plot.balanceOf(account.address);
      expect(plotsOwned.toString()).to.eq('1', 'Didn\'t receive back plot');

      const weedProductsOwned = await contracts.weedProduct.balanceOf(account.address);
      expect(weedProductsOwned.toString()).to.eq(
        (await contracts.weedProduct.getYield()).toString(),
        'Didn\'t receive plant yield'
      );

      const potatoProductsOwned = await contracts.potatoProduct.balanceOf(account.address);
      expect(potatoProductsOwned.toString()).to.eq(
        '0',
        'Didn\'t receive plant yield'
      );
    });

    it('Harvest plot - no longer growth season received weed', async function () {
      const options = {
        potatoGrowthSeasons: 1,
        potatoGrowthDuration: 15,
      };

      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);

      const latestBlock = await helpers.time.latestBlock();

      const seasonDuration = await contracts.farmSettings.SEASON_DURATION();
      
      // TODO: better use contract logic for seasons
      const justBeforeGrowthSeasonEnd = (seasonDuration * 5 - 10) - (latestBlock) % (seasonDuration * 4);
      await helpers.mine(justBeforeGrowthSeasonEnd);

      const plotId = '0';

      await buyApprovePlantPotato(contracts, account, plotId);
      await helpers.mine(15);

      const plant = await contracts.farm.getPlantByPlotId(plotId);

      if (plant.overgrownBlockNumber <= (await helpers.time.latestBlock() + 1)) {
        expect.fail('Plant overgrown block breached');
      }

      // HARVEST
      const receipt = await waitTx(contracts.farm.connect(account).harvest(plotId));
      const event = receipt.events.filter(e => e.event === 'HarvestOvergrown')[0];

      if (!event) { expect.fail('No HarvestOvergrown event'); }

      const userPlantIds = await contracts.farm.getUserPlantIds(account.address);
      expect(userPlantIds.length).to.eq(0, 'Plant still exists');

      const plotsOwned = await contracts.plot.balanceOf(account.address);
      expect(plotsOwned.toString()).to.eq('1', 'Didn\'t receive back plot');

      const weedProductsOwned = await contracts.weedProduct.balanceOf(account.address);
      expect(weedProductsOwned.toString()).to.eq(
        (await contracts.weedProduct.getYield()).toString(),
        'Didn\'t receive plant yield'
      );

      const potatoProductsOwned = await contracts.potatoProduct.balanceOf(account.address);
      expect(potatoProductsOwned.toString()).to.eq(
        '0',
        'Didn\'t receive plant yield'
      );
    });

    it('Should fail harvest plot - not enough water regen 0 water in plots', async function () {
      const options = {
        plotWaterRegenRate: 0,
        plotMaxWater: 1,
        potatoGrowthDuration: 1000,
      };

      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);
      const plotId = '1';

      await buyApprovePlantPotato(contracts, account, plotId);
      
      await helpers.mine(options.potatoGrowthDuration - 1);

      const receipt = await waitTx(contracts.farm.connect(account).harvest(plotId));
      const event = receipt.events.filter(e => e.event === 'HarvestNotEnoughWater')[0];
      if (!event) { expect.fail('No HarvestNotEnoughWater event'); }

      const { args } = contracts.farm.interface.parseLog(event);

      expect(args.plotId.toString()).to.equal(plotId);

      // plotId is 1, so there is no plot above it (plant gan absorb only from 4 plots)
      expect(args.waterAbsorbed.toString()).to.equal('4');

      // verify plant still exists
      const plantIds = await contracts.farm.getUserPlantIds(account.address);
      expect(plantIds.length).to.equal(1);
    });

    it('Should fail harvest plot - barely not enough water by 1 block', async function () {
      const options = {
        plotWaterRegenRate: 1,
        plantWaterAbsorbRate: 5,
        plotMaxWater: 249,
        potatoGrowthDuration: 1000,
        potatoMinWater: 1000 * 5,
      };

      // main plot water = 249 + 1 * (blocks plant to harvest) = 249 + 1000 = 1249
      // neighbor plot water = 249 + 1 * (blocks plant to harvest) = 249 + 1000 = 1249 (3 plots around)
      // total water available = 1249 + 1249 * 3 = 4996 (plant absorbs faster than regen)

      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);

      const plotId = '1';

      await buyApprovePlantPotato(contracts, account, plotId);
      await helpers.mine(options.potatoGrowthDuration - 1);

      const receipt = await waitTx(contracts.farm.connect(account).harvest(plotId));
      const event = receipt.events.filter(e => e.event === 'HarvestNotEnoughWater')[0];

      if (!event) { expect.fail('No HarvestNotEnoughWater event'); }

      const { args } = contracts.farm.interface.parseLog(event);

      expect(args.plotId.toString()).to.equal(plotId);
      expect(args.waterAbsorbed.toString()).to.equal('4996');
    });

    it('Should fail harvest plot - not enough water maximum neighbor plant number', async function () {
      // sum of all plot water would be just enough for a single plant to grow
      const options = {
        plotWaterRegenRate: 1,
        plantWaterAbsorbRate: 5,
        plotMaxWater: 250,
        potatoGrowthDuration: 1000,
        potatoMinWater: 1000 * 5,
      };

      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);

      // upper, right, lower, left, center
      const plotIds = ['1', '1002', '2001', '1000', '1001'];

      await buyApprovePlantPotato(contracts, account, plotIds[0]);
      await buyApprovePlantPotato(contracts, account, plotIds[1]);
      await buyApprovePlantPotato(contracts, account, plotIds[2]);
      await buyApprovePlantPotato(contracts, account, plotIds[3]);
      await buyApprovePlantPotato(contracts, account, plotIds[4]);

      await helpers.mine(options.potatoGrowthDuration - 1);

      const receipt = await waitTx(contracts.farm.connect(account).harvest(plotIds[4]));
      const event = receipt.events.filter(e => e.event === 'HarvestNotEnoughWater')[0];

      if (!event) { expect.fail('No HarvestNotEnoughWater event'); }

      const { args } = contracts.farm.interface.parseLog(event);

      expect(args.plotId.toString()).to.equal(plotIds[4]);

      // BEFORE CENTER STARTS ABSORBING
      
      // upper plant head start water absorbed - 20 blocks before center planted [has 3 neighbor plots]
      // (water absorbed 20 * 5 + 20 * 3 * 4 = 340)

      // right plant head start water absorbed - 15 blocks before center planted [has 4 neighbor plots]
      // (water absorbed 15 * 5 + 15 * 4 * 4 = 315)

      // lower plant head start water absorbed - 10 blocks before center planted [has 4 neighbor plots]
      // (water absorbed 10 * 5 + 10 * 4 * 4 = 210)

      // left plant head start water absorbed  - 5 blocks before center planted [has 3 neighbor plots]
      // (water absorbed 5 * 5 + 5 * 3 * 4 = 85)

      // neighbor plants stole 200 from center plot
      // 100 + 75 + 50 + 25 = 250 from their own centers (center plant neighbor plots)

      // AFTER CENTER STARTS ABSORBING
      // left in center (50 + 20) * 5/21 + regenerated 1000 * 5/21 = 254 goes to center plant [rounded]
      // extra due to rounding: center +1, upper +1, right +1
      
      // from upper neighbor (150 + 20) * 4/9 + 1000 * 4/9 = 520 goes to center plant [rounded]
      // extra due to rounding: (own plot center) upper +1

      // from right neighbor (175 + 15) * 4/9 + 1000 * 4/9 = 528 goes to center plant [rounded]
      // extra due to rounding: (own plot center) right +1

      // from lower neighbor (200 + 10) * 4/9 + 1000 * 4/9 = 537 goes to center plant [rounded]
      // extra due to rounding: (own plot center) lower +1

      // from left neighbor (225 + 5) * 4/9 + 1000 * 4/9 = 546 goes to center plant [rounded]
      // extra due to rounding: (own plot center) left +1

      // total water absorbed = 254 + 519 + 528 + 537 + 546 = 2384 + 1 (due to rounding)
      // due to rounding another 5 water may be absorbed

      // no neighbors 5000 - with neighbors 2386
      expect(args.waterAbsorbed.toString()).to.equal('2386');
    });

    // TODO: cleanup test
    it(`Harvest 3 plants - harvest 2, replant 1 in the same plot
      (checks plant array re-adding bug)`, async function () {
      // to provide enough blocks before overgrown for other transactions to execute
      const options = { potatoGrowthDuration: 20, potatoMinWater: 20 * 5 };
      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      await mintAndApproveTokens(contracts, account);

      const plotIds = ['0', '1'];

      // initial planting
      await buyApprovePlantPotato(contracts, account, plotIds[0]);
      await buyApprovePlantPotato(contracts, account, plotIds[1]);

      let plantIds = await contracts.farm.getUserPlantIds(account.address);
      expect(plantIds.map((p) => p.toString())).to.have.members(['0', '1']);

      // HARVEST (plot '0')
      await helpers.mine(options.potatoGrowthDuration - 1);
      await waitTx(contracts.farm.connect(account).harvest(plotIds[0]));

      // ---Replanting---

      // BUY MORE SEEDS
      await waitTx(
        contracts.farm
          .connect(account)
          .buySeeds(contracts.potatoSeed.address, 1)
      );

      // RE-APPROVE
      await approveTokens(
        contracts.potatoSeed,
        contracts.farm.address,
        account,
        1
      );
      await approveERC721Tokens(
        contracts.plot,
        contracts.farm.address,
        account,
        plotIds[0]
      );

      // RE-PLANTING (plot '0')
      await contracts.farm
        .connect(account)
        .plant(contracts.potatoSeed.address, plotIds[0]);

      plantIds = await contracts.farm.getUserPlantIds(account.address);
      expect(plantIds.map((p) => p.toString())).to.have.members(['0', '1']);

      // HARVEST (plot '1')
      await helpers.mine(1);
      await waitTx(contracts.farm.connect(account).harvest(plotIds[1]));

      plantIds = await contracts.farm.getUserPlantIds(account.address);
      expect(plantIds.map((p) => p.toString())).to.have.members(['0']);

      const plant1 = await contracts.farm.getPlantByPlotId(plotIds[1]);

      expect(plant1.plotId.toString()).to.eq('0', 'Plant plotId not matching');
      expect(plant1.seed).to.eq(
        '0x0000000000000000000000000000000000000000',
        'Plant seed address not matching'
      );
      expect(plant1.owner).to.eq(
        '0x0000000000000000000000000000000000000000',
        'Plant owner not matching'
      );

      const expectedProducts = '2';
      const productsOwned = await contracts.potatoProduct.balanceOf(
        account.address
      );
      expect(productsOwned.toString()).to.eq(
        expectedProducts,
        'Plant quantity not matching'
      );

      const expectedOwnedPlots = '1';
      const plotsReceivedByUser = await contracts.plot.balanceOf(
        account.address
      );
      expect(plotsReceivedByUser.toString()).to.eq(
        expectedOwnedPlots,
        'Didn\'t received expected plots'
      );
    });
  });
});
