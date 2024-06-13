const { expect } = require('chai');

const {
  mintTokens,
} = require('./helpers/utils');

const {
  setupContracts,
} = require('./helpers/setup');

// ******
let contracts;
let account;

describe('Season', function () {
  this.timeout(150000000);

  // *******************
  beforeEach('setup', async function () {
    const options = {};
    contracts = await setupContracts(options);
    [account] = await ethers.getSigners();

    await mintTokens(contracts.stableToken, account, 100);
  });

  describe('All seasons', async function () {
    it('Returns correct season for each block value of the year and beyond', async function () {
      const options = {
        seasonDuration: 300,
      };

      contracts = await setupContracts(options);
      [account] = await ethers.getSigners();

      let ABI = ['function getCurrentSeason(uint256 blockNumber, uint256 seasonDuration)'];
      let iface = new ethers.utils.Interface(ABI);


      // Winter from 0-299 (300)
      let encodedFn = iface.encodeFunctionData('getCurrentSeason', [0, 300]);

      let receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Winter begins bad seasons returns').to.be.equal(0);

      encodedFn = iface.encodeFunctionData('getCurrentSeason', [299, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Winter end bad seasons returns').to.be.equal(0);

      // Spring from 300-599 (300)
      encodedFn = iface.encodeFunctionData('getCurrentSeason', [300, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Spring begins bad seasons returns').to.be.equal(1);

      encodedFn = iface.encodeFunctionData('getCurrentSeason', [599, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Spring end bad seasons returns').to.be.equal(1);

      // Summer from 600-899 (300)
      encodedFn = iface.encodeFunctionData('getCurrentSeason', [600, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Summer begins bad seasons returns').to.be.equal(2);

      encodedFn = iface.encodeFunctionData('getCurrentSeason', [899, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Summer end bad seasons returns').to.be.equal(2);

      // Autumn from 900-1199 (300)
      encodedFn = iface.encodeFunctionData('getCurrentSeason', [900, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Autumn begins bad seasons returns').to.be.equal(3);

      encodedFn = iface.encodeFunctionData('getCurrentSeason', [1199, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(ethers.BigNumber.from(receipt).toNumber(), 'Autumn end bad seasons returns').to.be.equal(3);

      // Winter from 1200-1499 (300) - winter again after rotation
      encodedFn = iface.encodeFunctionData('getCurrentSeason', [1200, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(
        ethers.BigNumber.from(receipt).toNumber(),
        '[Post rotation] Winter begins bad seasons returns'
      ).to.be.equal(0);

      encodedFn = iface.encodeFunctionData('getCurrentSeason', [1499, 300]);

      receipt = await account.call({
        to: contracts.utilsTest.address,
        data: encodedFn,
      });

      expect(
        ethers.BigNumber.from(receipt).toNumber(),
        '[Post rotation] Winter end bad seasons returns'
      ).to.be.equal(0);
    });
  });
});
