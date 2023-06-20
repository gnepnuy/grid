// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";

contract SardinePool {

    address public immutable sardineFactory;
    address public baseToken;
    address public quoteToken;
    // uint256 public intervalPriceMin;对于可以创建任何交易对网格的协议来说，这两个参数的可以去掉了
    // uint256 public gridAmountMin;


    constructor(){
        sardineFactory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _baseToken, 
        address _quoteToken) external {
        require(msg.sender == sardineFactory, 'UniswapV2: FORBIDDEN'); // sufficient check
        baseToken = _baseToken;
        quoteToken = _quoteToken;
    }



}
