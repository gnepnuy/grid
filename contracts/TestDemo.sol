// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.7.6;

contract TestDemo {


    function testInt(int256 amount) external pure returns(uint256){
        
        return uint256(amount);
    }
}
