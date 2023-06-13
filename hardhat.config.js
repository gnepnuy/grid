require("@nomicfoundation/hardhat-toolbox");
const {key1,key2} = require("./private-key.json");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {
    },
    sepolia: {
      url: "https://sepolia.infura.io/v3/74d3de6db014405388a32e51189fb6fd",
      accounts: [key1, key2]
    }
  },
  solidity: {
    compilers: [
      // {
      //   version: "0.8.9",
      // },
      {
        version: "0.7.6",
        settings: {},
      },
    ],
  },
  etherscan: {
    apiKey: "9WN3PWJY4G2JHRQK1CX5NDZBT84J5F5SIK"
  }
};
