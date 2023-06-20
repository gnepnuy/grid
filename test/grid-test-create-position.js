const ethers = require("ethers");
const {key1,key2} = require("../private-key.json");
const grid_abi = require("../artifacts/contracts/Grid.sol/Grid.json").abi;
const erc20_abi = require("../artifacts/contracts/TestCoin.sol/TestCoin.json").abi;


const url = "https://sepolia.infura.io/v3/74d3de6db014405388a32e51189fb6fd"; 
let provider = new ethers.providers.JsonRpcProvider(url);
const grid_address = "0x8B2B6D2dc83C45968B14185C8697f1B4858E9b00";
const stable_address = "0x486022ECaF84E55989B94cF3424430d11c39Ba25";



async function main() {

  const account = new ethers.Wallet(key2,provider);
  const grid_contract = new ethers.Contract(grid_address,grid_abi,account);
  const stable_contract = new ethers.Contract(stable_address,erc20_abi,account);
  //先看看价格
  const price = (await grid_contract.getPrice()).toString()/10**6;
  console.log("current price: ",price);

  //buy
  const buy_tx = await grid_contract.buy(0);
  console.log("buy hash: ",buy_tx.hash);

  //sell
  // const sell_tx = await grid_contract.sell(1);
  // console.log("sell hash: ",sell_tx.hash);





                            



}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


function sleep(timeout) {
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        resolve();
      }, timeout);
    });
  }
