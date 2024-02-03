// SPDX-License-Identifier: MIT
// @author Tigran Arakelyan
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILiquidityLocker} from  "../interfaces/ILiquidityLocker.sol";

// LiquidityLocker holds custody of Liquidity Asset tokens for a given Pool
contract LiquidityLocker is ILiquidityLocker {
    using SafeERC20 for IERC20;

    address public immutable pool; // The Pool that owns this LiquidityLocker.
    IERC20 public immutable liquidityAsset; // The Liquidity Asset which this LiquidityLocker will escrow

    constructor(address _liquidityAsset, address _pool) {
        require(_liquidityAsset != address(0), "LL:ZERO_LIQ_ASSET");
        require(_pool != address(0), "LL:ZERO_P");
        liquidityAsset = IERC20(_liquidityAsset);

        pool = _pool;
    }

    // Transfers amount of Liquidity Asset to a destination account. Only the Pool can call this function
    function transfer(address _to, uint256 _amount) external override isPool returns (bool) {
        liquidityAsset.safeTransfer(_to, _amount);
        return true;
    }

    function totalBalance() external view returns (uint256) {
        return IERC20(liquidityAsset).balanceOf(address(this));
    }

    /*
    Modifiers
    */

    // Checks that `msg.sender` is the Pool
    modifier isPool() {
        require(msg.sender == pool, "LL:NOT_P");
        _;
    }
}
