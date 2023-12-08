// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface ILiquidityLocker {
    function transfer(address dst, uint256 amount) external returns (bool);

    function totalBalance() external view returns (uint256);

    function assetsExists(address _assetAddr) external returns (bool);
}
