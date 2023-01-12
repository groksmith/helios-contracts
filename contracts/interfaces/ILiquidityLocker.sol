// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidityLocker {
    function transfer(address dst, uint256 amt) external returns (bool);

    function balance() external view returns (uint256);

    function approve(address borrower, uint256 amt) external returns (bool);
}
