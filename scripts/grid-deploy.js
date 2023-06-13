// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  /**
        address _factory,
        address _weth,
        address _stable,
        uint24 fee,
        uint256 _interval_price_min,
        uint256 _grid_amount_min,
        uint256 _base_bounty_eth,
        uint256 _base_bounty_stable
   */
  const factory = "0x0227628f3F023bb0B980b67D528571c95c6DaC1c";
  const weth = "0xbF820766ec149C9220D97242Da58e9Ece20CC516";
  const stable = "0x486022ECaF84E55989B94cF3424430d11c39Ba25";
  const fee = "500";
  const interval_price_min = "30";
  const grid_amount_min = "5";
  const base_bounty_eth = "300000000000000";
  const base_bounty_stable = "2000000000000000000";

  const Grid = await hre.ethers.getContractFactory("Grid");
  const grid = await Grid.deploy(factory,weth,stable,fee,interval_price_min,grid_amount_min,base_bounty_eth,base_bounty_stable);
  await grid.deployed();

  console.log(" the grid contract address is: ",grid.address);

  // const TestCoin = await hre.ethers.getContractFactory("TestCoin");
  // let name = "TEST ETH";
  // let symbol = "TETH";
  // const totalSupply = "100000000000000000000000000"
  // const teth = await TestCoin.deploy(name,symbol,totalSupply);
  // await teth.deployed();
  // console.log("TETH address is :",teth.address);

  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
