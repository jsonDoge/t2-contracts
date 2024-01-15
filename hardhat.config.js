require('@nomiclabs/hardhat-ethers');
require('hardhat-contract-sizer');
require('solidity-coverage');

const { testnetPrivateKey } = require('./config.secret.js');

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    polygonMumbai: {
      url: 'https://rpc-mumbai.maticvigil.com',
      chainId: 80001,
      accounts: [testnetPrivateKey]
    },
  },
  solidity: {
    version: '0.8.22',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      }
    }
  },
  namedAccounts: {
    deployer: 0,
  },
  paths: {
    sources: './contracts',
    tests: './test',
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
};
