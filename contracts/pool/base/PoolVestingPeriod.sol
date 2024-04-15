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
        _updateHolder(msg.sender, to);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint amount) public override returns (bool) {
        _updateHolder(msg.sender, to);
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
            uint256 balance = balanceOf(_holder);

            effectiveDepositDate = (balance + _amount) > 0
                ? prevEffectiveDepositDate + (((block.timestamp - prevEffectiveDepositDate) * (_amount)) / (balance + _amount))
                : prevEffectiveDepositDate;
        }

        holdersToEffectiveDepositDate.set(_holder, effectiveDepositDate);

        totalInvested += _amount;
    }

    /// @notice Update lockup period for a holder
    /// @dev Add the holder to holders AddressMap
    function _updateHolder(address _oldHolder, address _newHolder) internal {
        if (_oldHolder == address(0)) revert InvalidHolder();
        if (_newHolder == address(0)) revert InvalidHolder();

        if (holdersToEffectiveDepositDate.contains(_oldHolder)) {
            uint256 lockupPeriod = holdersToEffectiveDepositDate.get(_oldHolder);
            holdersToEffectiveDepositDate.set(_oldHolder, lockupPeriod);
        }
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