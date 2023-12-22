// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILiquidityLocker {
    function transfer(address dst, uint256 amount) external returns (bool);

    function totalBalance() external view returns (uint256);

    function liquidityAsset() external view returns (IERC20);

    function assetsExists(address _assetAddr) external returns (bool);

    function setSecondaryLiquidityAsset(address _liquidityAsset) external;

    function deleteSecondaryLiquidityAsset(address _liquidityAsset) external;

    function setSecondaryLiquidityAssets(address[] calldata _liquidityAssets) external;
}
