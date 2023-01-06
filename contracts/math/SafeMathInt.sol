// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.1;

library SafeMathInt {
    function toUint256Safe(int256 a) internal pure returns (uint256) {
        require(a >= 0, "SMI:NEG");
        return uint256(a);
    }
}