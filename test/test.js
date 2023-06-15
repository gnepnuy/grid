const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
const { ethers } = require("hardhat");
  
  describe("Grid", function () {
    
  
  
    describe("CreateGrid", function () {
      describe("Validations", function () {
        it("test", async function () {
            const provider = ethers.getDefaultProvider();
            const blockNumber = await provider.getBlockNumber();
            console.log(blockNumber);

            console.log(await provider.getBalance('0x2546BcD3c84621e976D8185a91A922aE77ECEc30'))
          
  
        });
  
       
      });
  
    
    });
  
    
  
   
  });
  