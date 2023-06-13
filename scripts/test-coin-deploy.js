// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const TestCoin = await hre.ethers.getContractFactory("TestCoin");
  let name = "TEST ETH";
  let symbol = "TETH";
  let decimals = 18;
  const totalSupply = "100000000000000000000000000"
  const teth = await TestCoin.deploy(name,symbol,totalSupply,decimals);
  await teth.deployed();
  console.log("TETH address is :",teth.address);


  name = "TEST USDC";
  symbol = "TUSDC";
  decimals = 6;
  const tusdc = await TestCoin.deploy(name,symbol,totalSupply,decimals);
  await tusdc.deployed();
  console.log("TUSDC address is :",tusdc.address);

  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // const unlockTime = currentTimestampInSeconds + 60;

  // const lockedAmount = hre.ethers.utils.parseEther("0.001");

  // const Lock = await hre.ethers.getContractFactory("Lock");
  // const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

  // await lock.deployed();

  // console.log(
  //   `Lock with ${ethers.utils.formatEther(
  //     lockedAmount
  //   )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`
  // );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
