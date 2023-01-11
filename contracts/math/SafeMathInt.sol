// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMathInt {
    function toUint256Safe(int256 a) internal pure returns (uint256) {
        require(a >= 0, "SMI:NEG");
        return uint256(a);
    }
}