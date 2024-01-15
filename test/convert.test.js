const { expect } = require('chai');

const {
  waitTx,
  approveTokens,
  mintTokens,
  expectToFailWithMessage,
  buyApprovePlantPotato,
} = require('./helpers/utils');
const helpers = require('@nomicfoundation/hardhat-network-helpers');

const {
  setupContracts,
} = require('./helpers/setup');

// ******
let contracts;
let account;

describe('Convert', function () {
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

  // will only work if GROWTH_DURATION IS DISABLED
  describe('Convert product to seed', async function () {
    it('Should fail convert 1 product to 1 seed - not accepted product', async function () {
      const ERC20 = await ethers.getContractFactory('ERC20Mintable');
      const fakeProduct = await ERC20.deploy('FakeProduct', 'FP');
      await fakeProduct.deployTransaction.wait();

      await waitTx(fakeProduct.connect(account).mint(account.address, 10));

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).convertProductsToSeeds(fakeProduct.address, 1)
        ),
        'PRODUCT_NOT_CONVERTIBLE_TO_SEED'
      );
    });

    it('Should fail convert 1 product to 1 seed - no product allowance', async function () {
      const potatoGrowthDuration = await contracts.potatoSeed.getGrowthDuration();
      const plotId = '0';

      await buyApprovePlantPotato(contracts, account, plotId);

      await helpers.mine(potatoGrowthDuration);
      await contracts.farm.connect(account).harvest(plotId);

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).convertProductsToSeeds(contracts.potatoProduct.address, 1)
        ),
        `ERC20InsufficientAllowance("${contracts.farm.address}`
      );
    });

    it('Convert 1 product to 1 seed', async function () {
      const potatoGrowthDuration = await contracts.potatoSeed.getGrowthDuration();
      const plotId = '0';

      await buyApprovePlantPotato(contracts, account, plotId);

      await helpers.mine(potatoGrowthDuration - 1);
      await contracts.farm.connect(account).harvest(plotId);

      const productsBeforeConvert = (await contracts.potatoProduct.balanceOf(account.address)).toNumber();
      const seedsBeforeConvert = (await contracts.potatoSeed.balanceOf(account.address)).toNumber();

      await approveTokens(contracts.potatoProduct, contracts.farm.address, account, 1);
      await contracts.farm.connect(account).convertProductsToSeeds(contracts.potatoProduct.address, 1);

      expect((await contracts.potatoSeed.balanceOf(account.address)).toString())
        .to.eq((seedsBeforeConvert + 1).toString(), 'Incorrect quantity of seeds received');
      expect((await contracts.potatoProduct.balanceOf(account.address)).toString())
        .to.eq((productsBeforeConvert - 1).toString(), 'Incorrect quantity of products lost');
    });
  });

  // will only work if GROWTH_DURATION IS DISABLED
  describe('Convert product to dish', async function () {
    it('Should fail convert 3 products to 1 dish - non-existing recipe', async function () {
      const ERC20 = await ethers.getContractFactory('ERC20Mintable');
      const fakeProduct = await ERC20.deploy('FakeProduct', 'FP');
      await fakeProduct.deployTransaction.wait();

      await waitTx(fakeProduct.connect(account).mint(account.address, 10));

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).convertProductsToDish(
            [fakeProduct.address],
            [3]
          )
        ),
        'RECIPE_DOES_NOT_EXIST'
      );
    });

    it('Should fail convert 3 products to 1 dish - no product allowance', async function () {
      const potatoGrowthDuration = await contracts.potatoSeed.getGrowthDuration();
      
      const plotId0 = '0';
      await buyApprovePlantPotato(contracts, account, plotId0);
      await helpers.mine(potatoGrowthDuration - 1);
      await contracts.farm.connect(account).harvest(plotId0);

      const plotId1 = '1';
      await buyApprovePlantPotato(contracts, account, plotId1);
      await helpers.mine(potatoGrowthDuration - 1);
      await contracts.farm.connect(account).harvest(plotId1);
      
      const plotId2 = '2';
      await buyApprovePlantPotato(contracts, account, plotId2);
      await helpers.mine(potatoGrowthDuration - 1);
      await contracts.farm.connect(account).harvest(plotId2);

      await expectToFailWithMessage(
        waitTx(
          contracts.farm.connect(account).convertProductsToDish(
            [contracts.potatoProduct.address],
            [3]
          )
        ),
        `ERC20InsufficientAllowance("${contracts.farm.address}`
      );
    });

    it('Convert 3 products to 1 dish', async function () {
      const potatoGrowthDuration = await contracts.potatoSeed.getGrowthDuration();
      
      const plotId0 = '0';
      await buyApprovePlantPotato(contracts, account, plotId0);
      await helpers.mine(potatoGrowthDuration - 1);
      await contracts.farm.connect(account).harvest(plotId0);

      const plotId1 = '1';
      await buyApprovePlantPotato(contracts, account, plotId1);
      await helpers.mine(potatoGrowthDuration - 1);
      await contracts.farm.connect(account).harvest(plotId1);
      
      const plotId2 = '2';
      await buyApprovePlantPotato(contracts, account, plotId2);
      await helpers.mine(potatoGrowthDuration - 1);
      await contracts.farm.connect(account).harvest(plotId2);

      await approveTokens(contracts.potatoProduct, contracts.farm.address, account, 3);

      const dishesOwnedBeforeConvert = (await contracts.potatoDish.balanceOf(account.address)).toNumber();
      const productsOwnedBeforeConvert = (await contracts.potatoProduct.balanceOf(account.address)).toNumber();

      await waitTx(
        contracts.farm.connect(account)
          .convertProductsToDish(
            [contracts.potatoProduct.address],
            [3]
          )
      );

      const dishesAfterConvert = await contracts.potatoDish.balanceOf(account.address);
      expect(dishesAfterConvert.toString())
        .to.eq((dishesOwnedBeforeConvert + 1).toString(), 'Dish not received after convert');

      const productAfterConvert = await contracts.potatoProduct.balanceOf(account.address);
      expect(productAfterConvert.toString())
        .to.eq((productsOwnedBeforeConvert - 3).toString(), 'Products not used received after convert');
    });
  });
});
