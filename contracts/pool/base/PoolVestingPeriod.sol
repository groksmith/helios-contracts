// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {PoolBase} from "./PoolBase.sol";

/// @title Base contract for Pool with Vesting period
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract PoolVestingPeriod is PoolBase {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private holdersToUnlockTime;

    constructor(address _asset, string memory _tokenName, string memory _tokenSymbol)
    PoolBase(_asset, _tokenName, _tokenSymbol) {}

    /*
    ERC20 overrides
    */

    function transfer(address to, uint amount) public override returns (bool) {
        // TODO: transfer lock
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint amount) public override returns (bool) {
        // TODO: transfer lock
        return super.transferFrom(from, to, amount);
    }

    /*
    Helpers
    */

    /// @notice Get the count of holders
    function getHoldersCount() public view returns (uint256) {
        return holdersToUnlockTime.length();
    }

    /// @notice Get holders
    function getHolders() public view returns (address[] memory) {
        return holdersToUnlockTime.keys();
    }

    /// @notice Return true if holder exists
    function holderExists(address _holder) public view returns (bool) {
        return holdersToUnlockTime.contains(_holder);
    }

    /// @notice Get the holder address by index
    function getHolderByIndex(uint256 _index) public view returns (address) {
        if (_index >= holdersToUnlockTime.length()) revert InvalidIndex();
        (address key, uint256 value) = holdersToUnlockTime.at(_index);
        return key;
    }

    /// @notice check how much funds already unlocked
    /// @param _holder to be checked
    function unlockedToWithdraw(address _holder) public view returns (uint256) {
        return _tokensUnlocked(_holder) == true ? balanceOf(_holder) : 0;
    }

    /// @notice Add an investment for a holder
    /// @dev Add the holder to holders AddressMap
    function _addInvestment(address _holder, uint256 _amount, uint256 _unlockTime) internal {
        if (_holder == address(0)) revert InvalidHolder();
        if (_amount == 0) revert ZeroAmount();
        if (_unlockTime <= block.timestamp) revert WrongUnlockTime();

        holdersToUnlockTime.set(_holder, _unlockTime);

        totalInvested += _amount;
    }

    //    function updateDepositDate(
//        mapping(address => uint256) storage depositDate,
//        uint256 balance,
//        uint256 amount,
//        address account
//    ) internal {
//        uint256 prevDate = depositDate[account];
//
//        uint256 newDate = (balance + amount) > 0
//            ? prevDate.add(block.timestamp.sub(prevDate).mul(amount).div(balance + amount))
//            : prevDate;
//
//        depositDate[account] = newDate;
//        emit DepositDateUpdated(account, newDate);
//    }

    /// @notice Get lock status of a specific holder
    function _tokensUnlocked(address _holder) internal view returns (bool) {
        if (holdersToUnlockTime.contains(_holder) == false) revert InvalidHolder();

        return holdersToUnlockTime.get(_holder) < block.timestamp;
    }

    /*
    Modifiers
    */

    /// @notice Check if tokens unlocked
    modifier unlocked(address _holder) {
        if (_tokensUnlocked(_holder) == false) revert TokensLocked();
        _;
    }
}