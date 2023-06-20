const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const erc20_abi = require("../artifacts/contracts/IDecimalERC20.sol/IDecimalERC20.json").abi;

describe("Test", function () {

  async function deploy() {

    const TestDemo = await ethers.getContractFactory("TestDemo");
    const testDemo = await TestDemo.deploy();
    return testDemo;
  }

  describe("Test", function () {


    describe("testInt", function () {
      it("getValue", async function () {
        const testDemo = await loadFixture(deploy);

        console.log(await testDemo.testInt(100));
      });

     
    });

  
  });
 
});