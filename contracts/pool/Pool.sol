// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {AbstractPool} from "./AbstractPool.sol";
import {BlendedPool} from "./BlendedPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";

/// @title Regional Pool implementation
/// @author Tigran Arakelyan
contract Pool is AbstractPool {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    enum State {Active, Closed/*, Deactivated*/}
    State public poolState;

    event PoolStateChanged(State state);

    constructor(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount,
        uint256 _investmentPoolSize,
        string memory _tokenName,
        string memory _tokenSymbol)
    AbstractPool(_asset, _tokenName, _tokenSymbol) {
        poolInfo = PoolInfo(_lockupPeriod, _minInvestmentAmount, _investmentPoolSize);

        poolState = State.Active;
        emit PoolStateChanged(poolState);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    /// @param _amount the amount of assets to deposit
    function deposit(uint256 _amount) public override whenProtocolNotPaused nonReentrant inState(State.Active) {
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");

        super.deposit(_amount);
    }

    /// @notice Called only from Blended Pool. Part of BP compensation mechanism
    /// @param _amount the amount of assets to deposit
    function blendedPoolDeposit(uint256 _amount) external
    onlyBlendedPool whenProtocolNotPaused inState(State.Closed) {
        super.deposit(_amount);
    }

    /// @notice withdraws the caller's assets
    /// @param _amount the amount of assets to be withdrawn
    function withdraw(uint256 _amount) public override nonReentrant whenProtocolNotPaused {
        require(balanceOf(msg.sender) >= _amount, "P:INSUFFICIENT_FUNDS");
        require(unlockedToWithdraw(msg.sender) >= _amount, "P:TOKENS_LOCKED");

        if (principalBalanceAmount < _amount) {
            uint256 insufficientAmount = _amount - principalBalanceAmount;

            BlendedPool blendedPool = BlendedPool(poolFactory.getBlendedPool());

            // are we toking about same token?
            bool sameToken = (asset == blendedPool.asset());

            // Make sure there is enough funds in Blended Pool to invest
            bool blendedPoolCapableToCoverInsufficientAmount = (insufficientAmount < blendedPool.totalBalance());

            // skip requesting "BP Compensation" for Blended Pool. It doesn't make sense.
            bool actorIsNotBlendedPool = (msg.sender != address(blendedPool));

            bool inCorrectState = poolState == State.Closed;

            // Validate that we want to do automatic "BP Compensation"
            if (sameToken && blendedPoolCapableToCoverInsufficientAmount && actorIsNotBlendedPool && inCorrectState)
            {
                _burn(msg.sender, _amount);

                // Borrow liquidity from Blended Pool to Regional Pool
                // Return back to Blended Pool equal amount of Regional Pool's tokens (so now Blended Pool act as investor for Regional Pool)
                blendedPool.requestAssets(insufficientAmount);

                // Now we have liquidity
            } else {
                // Ok, going to manual flow
                (, uint256 currentValue) = pendingWithdrawals.tryGet(msg.sender);
                uint256 updatedValue = currentValue + _amount;
                pendingWithdrawals.set(msg.sender, updatedValue);

                emit PendingWithdrawal(msg.sender, _amount);
                return;
            }
        }
        else
        {
            _burn(msg.sender, _amount);
        }

        _emitBalanceUpdatedEvent();
        emit Withdrawal(msg.sender, _amount);

        _transferAssets(msg.sender, _amount);
    }

    /*
    Admin flow
    */

    function borrow(address _to, uint256 _amount) public override nonReentrant inState(State.Closed) {
        super.borrow(_to, _amount);
    }

    function repay(uint256 _amount) public override nonReentrant inState(State.Closed) {
        super.repay(_amount);
    }

    /// @notice Finalize pool, disable any new deposits
    function close() external onlyAdmin inState(State.Active) {
        poolState = State.Closed;
        emit PoolStateChanged(poolState);
    }

    /// @notice Check if pool in given state
    modifier inState(State _state) {
        require(poolState == _state, "P:BAD_STATE");
        _;
    }

    /// @notice Check if blended pool calling
    modifier onlyBlendedPool() {
        require(poolFactory.getBlendedPool() == msg.sender, "P:NOT_BP");
        _;
    }
}
