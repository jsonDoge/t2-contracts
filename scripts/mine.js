
const helpers = require('@nomicfoundation/hardhat-network-helpers');

async function main() {
  await helpers.mine(1);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
