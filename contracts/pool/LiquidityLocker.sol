// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ILiquidityLocker.sol";

contract LiquidityLocker is ILiquidityLocker {
    using SafeERC20 for IERC20;

    address public immutable pool;            // The Pool that owns this LiquidityLocker.
    IERC20  public immutable liquidityAsset;  // The Liquidity Asset which this LiquidityLocker will escrow.

    constructor(address _liquidityAsset, address _pool) {
        require(_liquidityAsset != address(0), "LL:ZERO_LIQ_ASSET");
        require(_pool != address(0), "LL:ZERO_P");
        liquidityAsset = IERC20(_liquidityAsset);
        pool = _pool;
    }

    function transfer(address dst, uint256 amt) external override isPool returns (bool) {
        require(dst != address(0), "LL:NULL_DST");
        liquidityAsset.safeTransfer(dst, amt);
        return true;
    }

    function balance() external view override isPool returns (uint256) {
        return liquidityAsset.balanceOf(address(pool));
    }

    function approve(address borrower, uint256 amt) external isPool returns (bool) {
        liquidityAsset.safeApprove(borrower, amt);
        return true;
    }

    modifier isPool() {
        require(msg.sender == pool, "LL:NOT_P");
        _;
    }
}