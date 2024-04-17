// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {PoolBase} from "./PoolBase.sol";

/// @title Base contract for Pool with Vesting period
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract PoolVestingPeriod is PoolBase {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private holdersToEffectiveDepositDate;

    constructor(address _asset, string memory _tokenName, string memory _tokenSymbol)
    PoolBase(_asset, _tokenName, _tokenSymbol) {}

    /*
    ERC20 overrides
    */

    function transfer(address to, uint amount) public override returns (bool) {
        _updateHolder(msg.sender, to, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint amount) public override returns (bool) {
        _updateHolder(msg.sender, to, amount);
        return super.transferFrom(from, to, amount);
    }

    /*
    Helpers
    */

    /// @notice Get the count of holders
    function getHoldersCount() public view returns (uint256) {
        return holdersToEffectiveDepositDate.length();
    }

    /// @notice Get holders
    function getHolders() public view returns (address[] memory) {
        return holdersToEffectiveDepositDate.keys();
    }

    /// @notice Return true if holder exists
    function holderExists(address _holder) public view returns (bool) {
        return holdersToEffectiveDepositDate.contains(_holder);
    }

    /// @notice Get the holder address by index
    function getHolderByIndex(uint256 _index) public view returns (address) {
        if (_index >= holdersToEffectiveDepositDate.length()) revert InvalidIndex();
        (address key,) = holdersToEffectiveDepositDate.at(_index);
        return key;
    }

    /// @notice Get the holder address by index
    function getHolderUnlockDate(address _holder) public view returns (uint256) {
        if (!holdersToEffectiveDepositDate.contains(_holder)) revert InvalidHolder();
        return holdersToEffectiveDepositDate.get(_holder) + poolInfo.lockupPeriod;
    }

    /// @notice check how much funds already unlocked
    /// @param _holder to be checked
    function unlockedToWithdraw(address _holder) public view returns (uint256) {
        return _tokensUnlocked(_holder) == true ? balanceOf(_holder) : 0;
    }

    /// @notice Update lockup period for a holder
    /// @dev Add the holder to holders AddressMap
    function _updateEffectiveDepositDate(address _holder, uint256 _amount) internal {
        if (_holder == address(0)) revert InvalidHolder();
        if (_amount == 0) revert ZeroAmount();

        uint256 effectiveDepositDate = block.timestamp;

        if (holdersToEffectiveDepositDate.contains(_holder)) {
            uint256 prevEffectiveDepositDate = holdersToEffectiveDepositDate.get(_holder);

            effectiveDepositDate = _calculateEffectiveDepositDate(
                _amount,
                block.timestamp,
                balanceOf(_holder),
                prevEffectiveDepositDate
            );
        }

        holdersToEffectiveDepositDate.set(_holder, effectiveDepositDate);

        totalInvested += _amount;
    }

    /// @notice Update lockup period for a holder
    /// @dev Add the holder to holders AddressMap
    function _updateHolder(address _from, address _to, uint256 _amount) internal {
        if (_from == address(0)) revert InvalidHolder();
        if (_to == address(0)) revert InvalidHolder();

        if (holdersToEffectiveDepositDate.contains(_from)) {
            uint256 effectiveDepositDateFrom = holdersToEffectiveDepositDate.get(_from);

            if (holdersToEffectiveDepositDate.contains(_to)) {
                uint256 effectiveDepositDateTo = holdersToEffectiveDepositDate.get(_to);
                uint256 initialBalance = balanceOf(_to);
                uint256 effectiveDepositDate = _calculateEffectiveDepositDate(
                    _amount,
                    effectiveDepositDateFrom,
                    initialBalance,
                    effectiveDepositDateTo
                );

                holdersToEffectiveDepositDate.set(_to, effectiveDepositDate);
            }
            else
            {
                holdersToEffectiveDepositDate.set(_to, effectiveDepositDateFrom);
            }
        }
    }

    function _calculateEffectiveDepositDate(
        uint256 _amountFrom,
        uint256 _effectiveDepositDateFrom,
        uint256 _amountTo,
        uint256 _effectiveDepositDateTo) internal pure returns (uint256){

        if (_amountTo == 0)
        {
            return _effectiveDepositDateFrom;
        }

        uint256 impactRate = _amountFrom / _amountTo;

        return _effectiveDepositDateTo + ((impactRate / (impactRate + 1)) * (_effectiveDepositDateFrom - _effectiveDepositDateTo));
    }

    /// @notice Get lock status of a specific holder
    function _tokensUnlocked(address _holder) internal view returns (bool) {
        if (!holdersToEffectiveDepositDate.contains(_holder)) revert InvalidHolder();

        return holdersToEffectiveDepositDate.get(_holder) + poolInfo.lockupPeriod <= block.timestamp;
    }

    /*
    Modifiers
    */

    /// @notice Check if tokens unlocked
    modifier unlocked(address _holder) {
        if (!_tokensUnlocked(_holder)) revert TokensLocked();
        _;
    }
}