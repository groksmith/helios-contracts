// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";


import {PoolBase} from "./PoolBase.sol";

/// @title Base contract for Pool with vesting period
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract PoolVestingPeriod is PoolBase {
    using Math for uint256;
    using SignedMath for int256;

    using SafeCast for int256;
    using SafeCast for uint256;

    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private holdersToEffectiveDepositDate;

    constructor(address _asset, string memory _tokenName, string memory _tokenSymbol)
    PoolBase(_asset, _tokenName, _tokenSymbol) {}

    /*
    ERC20 overrides
    */

    function transfer(address to, uint amount) whenProtocolNotPaused public override returns (bool) {
        _updateHolder(msg.sender, to, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint amount) whenProtocolNotPaused public override returns (bool) {
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
    function getHolders() external view returns (address[] memory) {
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

    /// @notice Get holder's deposit unlock timestamp
    /// @param _holder to be checked
    function getHolderUnlockDate(address _holder) public view returns (uint256) {
        if (!holdersToEffectiveDepositDate.contains(_holder)) revert InvalidHolder();
        return holdersToEffectiveDepositDate.get(_holder) + poolInfo.lockupPeriod;
    }

    /// @notice check how much funds already unlocked
    /// @param _holder to be checked
    function unlockedToWithdraw(address _holder) public view returns (uint256) {
        return _tokensUnlocked(_holder) == true ? balanceOf(_holder) : 0;
    }

    /// @dev Updates the effective deposit date based on how much new capital has been added.
    ///      If more capital is added, the deposit date moves closer to added deposit date.
    /// @param _amount to be added to existing balance
    /// @param _depositDateOfAmount deposit date of amount
    /// @param _balance current balance
    /// @param _depositDateOfBalance current deposit date
    function calculateEffectiveDepositDate(
        uint256 _amount,
        uint256 _depositDateOfAmount,
        uint256 _balance,
        uint256 _depositDateOfBalance)
    public pure returns (uint256) {
        if (_balance == 0) return _depositDateOfAmount;
        if (_amount == 0) return _depositDateOfBalance;

        int256 dateDiff = _depositDateOfAmount.toInt256() - _depositDateOfBalance.toInt256();
        uint256 dateDiffModule = dateDiff.abs();

        if (_depositDateOfAmount >= _depositDateOfBalance)
        {
            return _depositDateOfBalance + ((_amount * dateDiffModule) / (_amount + _balance));
        }
        else
        {
            return _depositDateOfBalance - ((_amount * dateDiffModule) / (_amount + _balance));
        }
    }

    /// @notice Update lockup period for a holder
    /// @dev Add the holder to holders AddressMap
    function _updateEffectiveDepositDate(address _holder, uint256 _amount) internal {
        if (_holder == address(0)) revert InvalidHolder();
        if (_amount == 0) revert ZeroAmount();

        uint256 effectiveDepositDate = block.timestamp;

        if (holdersToEffectiveDepositDate.contains(_holder)) {
            uint256 prevEffectiveDepositDate = holdersToEffectiveDepositDate.get(_holder);

            effectiveDepositDate = calculateEffectiveDepositDate(
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
                uint256 effectiveDepositDate = calculateEffectiveDepositDate(
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