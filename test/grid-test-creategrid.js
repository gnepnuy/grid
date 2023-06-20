const ethers = require("ethers");
const {key1,key2} = require("../private-key.json");
const grid_abi = require("../artifacts/contracts/Grid.sol/Grid.json").abi;
const erc20_abi = require("../artifacts/contracts/TestCoin.sol/TestCoin.json").abi;


const url = "https://sepolia.infura.io/v3/74d3de6db014405388a32e51189fb6fd"; 
let provider = new ethers.providers.JsonRpcProvider(url);
const grid_address = "0x8B2B6D2dc83C45968B14185C8697f1B4858E9b00";
const stable_address = "0x486022ECaF84E55989B94cF3424430d11c39Ba25";



async function main() {
    const account = new ethers.Wallet(key1,provider);
    const grid_contract = new ethers.Contract(grid_address,grid_abi,account);
    const stable_contract = new ethers.Contract(stable_address,erc20_abi,account);
    //先看看价格
    const price = (await grid_contract.getPrice()).toString()/10**6;
    console.log("current price: ",price);

    // // //create buy grid
    // let create_grid_params = {
    //     side: 0,
    //     min_price: "1580000000",
    //     max_price: "1900000000",
    //     init_amount: "10000000000",
    //     interval_price: "10000000",
    //     share_amount: "1000000000"
    // };
    // let approve_tx = await stable_contract.approve(grid_address,create_grid_params.init_amount);
    // console.log("approve tx: ",approve_tx.hash);
    // await sleep(30_000);


    // let create_grid_tx = await grid_contract.createGrid(
    //                                 create_grid_params.side,
    //                                 create_grid_params.min_price,
    //                                 create_grid_params.max_price,
    //                                 create_grid_params.init_amount,
    //                                 create_grid_params.interval_price,
    //                                 create_grid_params.share_amount
    //                             );
    // console.log("create grid tx: ",create_grid_tx.hash);
    // await sleep(20_000);

    // // //create sell grid
    // create_grid_params = {
    //     side: 1,
    //     min_price: "1580000000",
    //     max_price: "1900000000",
    //     init_amount: "10000000000",
    //     interval_price: "10000000",
    //     share_amount: "1000000000"
    // };
    // approve_tx = await stable_contract.approve(grid_address,create_grid_params.init_amount);
    // console.log("approve tx: ",approve_tx.hash);
    // await sleep(30_000);


    // create_grid_tx = await grid_contract.createGrid(
    //                                 create_grid_params.side,
    //                                 create_grid_params.min_price,
    //                                 create_grid_params.max_price,
    //                                 create_grid_params.init_amount,
    //                                 create_grid_params.interval_price,
    //                                 create_grid_params.share_amount
    //                             );
    // console.log("create grid tx: ",create_grid_tx.hash);

    // await sleep(20_000);

    //create Bilateral grid
    create_grid_params = {
        side: 2,
        min_price: "1580000000",
        max_price: "1900000000",
        init_amount: "15000000000",
        interval_price: "10000000",
        share_amount: "1000000000"
    };
    approve_tx = await stable_contract.approve(grid_address,create_grid_params.init_amount);
    console.log("approve tx: ",approve_tx.hash);
    await sleep(30_000);


    create_grid_tx = await grid_contract.createGrid(
                                    create_grid_params.side,
                                    create_grid_params.min_price,
                                    create_grid_params.max_price,
                                    create_grid_params.init_amount,
                                    create_grid_params.interval_price,
                                    create_grid_params.share_amount
                                );
    console.log("create grid tx: ",create_grid_tx.hash);
                            



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
