// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {BlendedPool} from "./BlendedPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
    constructor(
        address _liquidityAsset,
        address _liquidityLockerFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_liquidityAsset, _liquidityLockerFactory, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo = PoolLibrary.PoolInfo(_lockupPeriod, _apy, _duration, _investmentPoolSize, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");

        _depositLogic(_amount, liquidityLocker.liquidityAsset());
    }

    function _calculateYield(address _holder, uint256 _amount) internal view override returns (uint256) {
        uint256 holderBalance = balanceOf(_holder);
        uint256 holderShare = (holderBalance * 1e18) / poolInfo.investmentPoolSize;
        return holderShare * _amount / 1e18;
    }

    /// @notice withdraws the caller's liquidity assets
    /// @param  _amounts the amount of Liquidity Asset to be withdrawn
    /// @param  _indices the indices of the DepositsHolder's DepositInstance
    function withdraw(uint256[] calldata _amounts, uint16[] calldata _indices) public override whenProtocolNotPaused {
        PoolLibrary.DepositInstance[] memory deposits = depositsHolder.getDepositsByHolder(msg.sender);

        require(_amounts.length == _indices.length, "P:ARRAYS_INCONSISTENT");
        require(_indices.length <= deposits.length, "P:ARRAYS_INCONSISTENT");

        uint256 totalBalance = liquidityLockerTotalBalance();
        BlendedPool blendedPool = BlendedPool(poolFactory.getBlendedPool());

        for (uint256 i = 0; i < _indices.length; i++) {
            uint256 _index = _indices[i];
            uint256 _amount = _amounts[i];

            require(block.timestamp >= deposits[_index].unlockTime, "P:TOKENS_LOCKED");
            require(deposits[_index].amount >= _amount, "P:INSUFFICIENT_FUNDS");

            // Check if there is sufficient amount
            if (totalBalance < _amount) {
                // We are out of funds. Don't panic.
                // Let's borrow funds from Blended Pool. BP Investors will be happy to participate in Regional Pool.

                // Calculate insufficient amount
                uint256 insufficientAmount = _amount - totalBalance;

                // are we toking about same token?
                bool sameToken = (liquidityAsset == blendedPool.liquidityAsset());

                // Make sure there is enough funds in Blended Pool to invest
                bool blendedPoolCapableToCoverInsufficientAmount = (insufficientAmount < blendedPool.liquidityLockerTotalBalance());

                // skip requesting "BP Compensation" for Blended Pool. It doesn't make sense.
                bool actorIsNotBlendedPool = (msg.sender != address(blendedPool));

                // Requested amount more than compensationThreshold. Will add in the next iteration.
                bool requestedAmountLessThanCompensationThreshold = true;

                // Validate that we want to do automatic "BP Compensation"
                if (sameToken &&
                    blendedPoolCapableToCoverInsufficientAmount &&
                    actorIsNotBlendedPool &&
                    requestedAmountLessThanCompensationThreshold)
                {
                    // Borrow liquidity from Blended Pool to Regional Pool
                    // Return back to Blended Pool equal amount of Regional Pool's tokens (so now Blended Pool act as investor for Regional Pool)
                    blendedPool.requestLiquidityAssets(insufficientAmount);
                } else {
                    // Ok, going to manual flow
                    pendingWithdrawals[msg.sender] += _amount;
                    emit PendingWithdrawal(msg.sender, _amount);
                    continue;
                }
            }

            // Finish withdraw process and burn investors portion of tokens (we have enough funds)
            _burn(msg.sender, _amount);
            deposits[_index].amount -= _amount;

            if (deposits[_index].amount == 0) {
                depositsHolder.deleteDeposit(msg.sender, _index);
            }

            _transferLiquidityLockerFunds(msg.sender, _amount);
            _emitBalanceUpdatedEvent();
            emit Withdrawal(msg.sender, _amount);
        }
    }
}

