// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface ILiquidityLocker {
    function transfer(address dst, uint256 amount) external returns (bool);

    function totalSupply() external returns (uint256);
}
