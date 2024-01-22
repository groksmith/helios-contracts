// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ILiquidityLocker.sol";

// LiquidityLocker holds custody of Liquidity Asset tokens for a given Pool
contract LiquidityLocker is ILiquidityLocker {
    using SafeERC20 for IERC20;

    address public immutable pool; // The Pool that owns this LiquidityLocker.
    IERC20 public immutable liquidityAsset; // The Liquidity Asset which this LiquidityLocker will escrow
    mapping(address => bool) public secondaryLiquidityAssets;

    constructor(address _liquidityAsset, address _pool) {
        require(_liquidityAsset != address(0), "LL:ZERO_LIQ_ASSET");
        require(_pool != address(0), "LL:ZERO_P");
        liquidityAsset = IERC20(_liquidityAsset);
        pool = _pool;
    }

    // Transfers amount of Liquidity Asset to a destination account. Only the Pool can call this function
    function transfer(address dst, uint256 amount) external override isPool returns (bool) {
        require(dst != address(0), "LL:NULL_DST");
        liquidityAsset.safeTransfer(dst, amount);
        return true;
    }

    function totalBalance() external view returns (uint256) {
        return IERC20(liquidityAsset).balanceOf(address(this));
    }

    function totalBalanceSecondary(address _assetAddr) external view returns (uint256) {
        return IERC20(_assetAddr).balanceOf(address(this));
    }

    function setSecondaryLiquidityAsset(address _liquidityAsset) external {
        secondaryLiquidityAssets[_liquidityAsset] = true;
    }

    function deleteSecondaryLiquidityAsset(address _liquidityAsset) external {
        delete secondaryLiquidityAssets[_liquidityAsset];
    }

    function setSecondaryLiquidityAssets(address[] calldata _liquidityAssets) external {
        for (uint256 i = 0; i <= _liquidityAssets.length; i++) {
            secondaryLiquidityAssets[_liquidityAssets[i]] = true;
        }
    }

    function secondaryAssetExists(address _assetAddr) external view returns (bool) {
        return secondaryLiquidityAssets[_assetAddr];
    }

    // Checks that `msg.sender` is the Pool
    modifier isPool() {
        require(msg.sender == pool, "LL:NOT_P");
        _;
    }
}
