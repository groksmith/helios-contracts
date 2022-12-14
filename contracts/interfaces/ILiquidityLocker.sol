// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidityLocker {
    function transfer(address dst, uint256 amt) external returns (bool);
}
