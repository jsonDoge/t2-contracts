const { expect } = require('chai');

async function waitTx(tx) {
  return (await tx).wait();
}

const approveTokens = async (
  tokenContract,
  approveForAddress,  
  approverAccount,
  quantityBN
) => 
  waitTx(
    tokenContract
      .connect(approverAccount)
      .approve(
        approveForAddress,
        quantityBN.toString()
      )
);

const approveERC721Tokens = async (
  tokenContract,
  approveForAddress,  
  approverAccount,
  tokenId
) => 
  waitTx(
    tokenContract
      .connect(approverAccount)
      .approve(
        approveForAddress,
        tokenId
      )
);

const mintTokens = async (tokenContract, account, quantity) =>   
  await waitTx(
    tokenContract
      .connect(account)
      .mint(account.address, quantity)
  );

const expectToFailWithMessage = async (promise, message) => {
  let hasFailed;
  try {
    await promise;
  } catch (e) {
    hasFailed = true;
    expect(e.toString().indexOf(message))
      .to.be.above(-1, `Tx failing with a wrong message ${e.toString()}`);
  }

  if (!hasFailed) {
    throw new Error('Did not fail');
  }
};

// Very reptitive code
const buyApprovePlantPotato = async (contracts, account, plotId) => {
  // BUY
  await waitTx(
    contracts.farm.connect(account).buyPlot(plotId)
  );
  await waitTx(
    contracts.farm.connect(account).buySeeds(contracts.potatoSeed.address, 1)
  );

  // APPROVE
  await approveTokens(contracts.potatoSeed, contracts.farm.address, account, 1);
  await approveERC721Tokens(contracts.plot, contracts.farm.address, account, plotId);

  // PLANT
  await waitTx(
    contracts.farm.connect(account).plant(contracts.potatoSeed.address, plotId)
  );
};

module.exports = {
  waitTx,
  approveTokens,
  approveERC721Tokens,
  mintTokens,
  expectToFailWithMessage,
  buyApprovePlantPotato
};