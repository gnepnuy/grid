const ethers = require("ethers");

const router = require("../artifacts/contracts/PancakeRouter.sol/PancakeRouter.json");
const IERC20 = require("../IERC20.json");

const url = "https://data-seed-prebsc-1-s1.binance.org:8545";
let provider = new ethers.JsonRpcProvider(url);
const privateKey = "2a34b1d40d32c33f67640727b28edc7c685e40ffedface10910437e8c79411db";
const router_address = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
const pair_address = "0x209ebd953fa5e3fe1375f7dd0a848a9621e9eafc";

const busd = "0xaB1a4d4f1D656d2450692D237fdD6C7f9146e814";
const cake = "0xFa60D973F7642B748046464e165A65B7323b0DEE";


//用涨跌幅推算兑换数量
async function main() {
  //需求：把cake 的价格拉升10个点

  const mainWallet = new ethers.Wallet(privateKey,provider);
  const router_contract = new ethers.Contract(router_address,router.abi,mainWallet);


  const busd_contract = new ethers.Contract(busd,IERC20,provider);
  const cake_contract = new ethers.Contract(cake,IERC20,provider);

  const busd_balance = await busd_contract.balanceOf(pair_address);
  console.log(ethers.formatEther(busd_balance));
  const cake_balance = await cake_contract.balanceOf(pair_address);
  console.log(ethers.formatEther(cake_balance));
  const cake_price = ethers.formatEther(busd_balance) / ethers.formatEther(cake_balance);

  console.log("交易前cake价格:",cake_price);//交易前cake价格

  const outAmount_cake = ethers.formatEther(cake_balance) * 0.1 / 2;//推算出大致要购买的cake数量 0.1 为涨跌幅百分比，2为固定值
  console.log("推算出大致要购买的cake数量:",outAmount_cake)
  
  const bigIntOutAmount_cake = ethers.parseEther(outAmount_cake.toString());
  const inAmount  = busd_balance *  bigIntOutAmount_cake / (cake_balance - bigIntOutAmount_cake);//计算出要花费的busd数量
  console.log("计算出要花费的busd数量:",inAmount)

  //去交易
  const cakeBalance = await cake_contract.balanceOf(mainWallet.address);//cake 的余额
    const inputAmount = inAmount;//用余额25%去兑换
    const allowance = await busd_contract.allowance(mainWallet.address,router_address);//查询用户地址给交易平台合约的授权额度
    if(allowance < inputAmount){
      const amount = "100000000000000000000000000000000000000000";//授权一个很大的额度，后面交易就不需要在授权了
      const tx = await busd_contract.approve(
        router_address,//授权合约地址，授权后这个地址可以转移用户地址的ERC20代币
        amount
      );//去授权
      console.log("approve hash:",tx.hash);
      await sleep(3000)
    }
    const path = [busd,cake];
    const outAmounts = await router_contract.getAmountsOut(inputAmount,path);
    const outAmount = outAmounts[1];//取输出数量
    const outAmountMin = outAmount - (outAmount * BigInt(5)/BigInt(1000));//滑点
    const deadline = parseInt(Date.now() / 1000) + 60;
    const tx = await router_contract.swapExactTokensForTokens(
      inputAmount,
      outAmountMin,
      path,
      mainWallet.address,
      deadline
    );
    console.log("swap hash:",tx.hash);

  await sleep(10000);

  const after_busd_balance = await busd_contract.balanceOf(pair_address);
  console.log(ethers.formatEther(after_busd_balance));
  const after_cake_balance = await cake_contract.balanceOf(pair_address);
  console.log(ethers.formatEther(after_cake_balance));
  const after_cake_price = ethers.formatEther(after_busd_balance) / ethers.formatEther(after_cake_balance);

  console.log("交易后cake价格:",after_cake_price);//交易后cake价格



  console.log("涨幅：",(after_cake_price - cake_price)/cake_price)



}




main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



// function sleep(ms) {
//     let start = Date.now()
//     let end = start + ms
//     while(true) {
//         if(Date.now() > end) {
//             return
//         }   
//     }
// }

// function sleep(ms) {
//     let temp = new Promise((resolve) => {
//         console.log("----------------------------------");
//         setTimeout(resolve,ms);
//     })
//     return temp
// }

function sleep(timeout) {
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        resolve();
      }, timeout);
    });
  }






