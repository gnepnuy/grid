const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const erc20_abi = require("../artifacts/contracts/IDecimalERC20.sol/IDecimalERC20.json").abi;

describe("Grid", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearGridFixture() {
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
    console.log(grid.address);
    console.log("fee: ",await grid.fee())


    const TestCoin = await hre.ethers.getContractFactory("TestCoin");
    let name = "TEST USDC";
    let symbol = "TUSDC";
    let decimals = 6;
    const totalSupply = "100000000000000000000000000"
    const tusdc = await TestCoin.deploy(name,symbol,totalSupply,decimals);
    await tusdc.deployed();
    console.log("tusdc address is :",tusdc.address);

    return { grid,tusdc };
  }

  async function deployOneYearGridFixtureV2() {
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
    console.log(grid.address);
    console.log("fee: ",await grid.fee());

    // const stable_contract = new ethers.Contract(stable,erc20_abi,ethers.getDefaultProvider());

    // const approve_tx = await stable_contract.approve(grid.address,10000000000);
    // console.log(approve_tx.hash);

    // const create_grid_tx = await grid.createGrid(1,1580000000,1900000000,10000000000,10000000,1000000000);
    // console.log(create_grid_tx.hash);
  }


  describe("CreateGrid", function () {
    describe("Validations", function () {
      it("test", async function () {
        await loadFixture(deployOneYearGridFixtureV2);
        

      });

     
    });

  
  });

  

  // describe("CreateGrid", function () {
  //   describe("Validations", function () {
  //     it("test", async function () {
  //       const { grid,tusdc } = await loadFixture(deployOneYearGridFixture);
        
  //       const create_grid_params = {
  //         side: "0",
  //         min_price: "1580000000",
  //         max_price: "1900000000",
  //         init_amount: "10000000000",
  //         interval_price: "10000000",
  //         share_amount: "1000000000"
  //       };
  //       const approve_tx = await tusdc.approve(grid.address,create_grid_params.init_amount);
  //       console.log("approve tx: ",approve_tx.hash);

  //       const data = await grid.call("createGrid", [0, 1580000000, 1900000000, _init_amount, _interval_price, _share_amount])

  //       // const create_grid_tx = await grid.createGrid(0,1580000000,1900000000,10000000000,10000000,1000000000);
  //       // console.log("create grid tx: ",create_grid_tx.hash);
 
  //     });

     
  //   });

  
  // });
});
