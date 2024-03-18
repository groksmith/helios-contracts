// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";
import {Pool} from "./Pool.sol";

/// @title Blended Pool implementation
/// @author Tigran Arakelyan
contract BlendedPool is AbstractPool {
    event RegPoolRequested(address indexed regPool, uint256 amount);

    constructor(address _asset, uint256 _lockupPeriod, uint256 _minInvestmentAmount)
    AbstractPool(_asset, NAME, SYMBOL) {
        poolInfo = PoolInfo(_lockupPeriod, _minInvestmentAmount, type(uint256).max);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    /// @param _amount the amount of assets to be deposited
    function deposit(uint256 _amount) public override notZero(_amount) whenProtocolNotPaused nonReentrant {
        super.deposit(_amount);
    }

    /// @notice withdraws the caller's liquidity assets
    /// @param _amount to be withdrawn
    function withdraw(uint256 _amount) public override nonReentrant whenProtocolNotPaused {
        require(balanceOf(msg.sender) >= _amount, "BP:INSUFFICIENT_FUNDS");
        require(unlockedToWithdraw(msg.sender) >= _amount, "BP:TOKENS_LOCKED");
        require(principalBalanceAmount >= _amount, "BP:NOT_ENOUGH_ASSETS");

        _burn(msg.sender, _amount);

        _emitBalanceUpdatedEvent();
        emit Withdrawal(msg.sender, _amount);

        _transferFunds(msg.sender, _amount);
    }

    /// @notice Only called by a RegPool when it doesn't have enough Assets
    /// @param _amount the amount requested for compensation
    function requestAssets(uint256 _amount) external notZero(_amount) nonReentrant onlyPool {
        require(principalBalanceAmount >= _amount, "BP:NOT_ENOUGH_ASSETS");

        Pool pool = Pool(msg.sender);
        bool success = asset.approve(address(pool), _amount);

        if (success)
        {
            emit RegPoolRequested(msg.sender, _amount);
            pool.blendedPoolDeposit(_amount);
        }
    }

    function borrow(address _to, uint256 _amount) public override nonReentrant {
        super.borrow(_to, _amount);
    }

    function repay(uint256 _amount) public override nonReentrant {
        super.repay(_amount);
    }

    /// @notice Only pool can call
    modifier onlyPool() {
        require(poolFactory.isValidPool(msg.sender), "P:NOT_POOL");
        _;
    }
}
