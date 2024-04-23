// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {PoolFunds} from "./PoolFunds.sol";

/// @title Base contract for pool yield distribution
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract PoolYieldDistribution is PoolFunds {
    using SafeERC20 for IERC20;

    uint256 public yieldBalanceAmount;
    mapping(address => uint256) public yields;

    event YieldWithdrawn(address indexed investor, address indexed receiver, uint256 amount);

    constructor(address _asset, string memory _tokenName, string memory _tokenSymbol)
    PoolFunds(_asset, _tokenName, _tokenSymbol) {}

    /// @notice Used to transfer the investor's yields to him
    /// @param _beneficiary will forward yield to address
    function withdrawYield(address _beneficiary) external virtual nonReentrant whenProtocolNotPaused returns (bool) {
        return _withdrawYield(msg.sender, _beneficiary);
    }

    /// @notice Used to transfer the investor's yields to reinvest
    /// @param _holder address
    /// @param _beneficiary address to forward yield to
    function withdrawYield(address _holder, address _beneficiary) external virtual onlyAdmin nonReentrant whenProtocolNotPaused returns (bool) {
        return _withdrawYield(_holder, _beneficiary);
    }

    /// @notice Repay and distribute yields
    /// @param _amount amount to be repaid
    function repayYield(uint256 _amount) public virtual notZero(_amount) nonReentrant onlyAdmin {
        if (asset.balanceOf(msg.sender) < _amount) revert NotEnoughBalance();

        uint256 count = getHoldersCount();
        for (uint256 i = 0; i < count; i++) {
            address holder = getHolderByIndex(i);
            yields[holder] += _calculateYield(holder, _amount);
        }

        _depositYieldsFrom(msg.sender, _amount);
    }

    /*
    Internals
    */

    /// @notice Calculate yield for specific holder
    /// @param _holder address of holder
    /// @param _amount to be shared proportionally
    function _calculateYield(address _holder, uint256 _amount) internal view virtual returns (uint256) {
        return (_amount * balanceOf(_holder)) / totalSupply();
    }

    /// @notice Used to transfer the investor's yields to beneficiary address
    function _withdrawYield(address _holder, address _beneficiary) internal returns (bool) {
        if (yields[_holder] == 0) revert ZeroYield();
        if (yieldBalanceAmount < yields[_holder]) revert InsufficientFunds();

        uint256 callerYields = yields[_holder];
        yields[_holder] = 0;

        emit YieldWithdrawn(_holder, _beneficiary, callerYields);

        _transferYields(_beneficiary, callerYields);
        return true;
    }

    /// @notice Transfers yield assets to given `_to` address
    /// @param _to receiver's address
    /// @param _value amount to be transferred
    function _transferYields(address _to, uint256 _value) internal {
        yieldBalanceAmount -= _value;
        if (!asset.transfer(_to, _value)) revert TransferFailed();
    }

    /// @notice Deposit yield assets from given `_from` address
    /// @param _from sender's address
    /// @param _value amount to be received
    function _depositYieldsFrom(address _from, uint256 _value) internal {
        yieldBalanceAmount += _value;
        asset.safeTransferFrom(_from, address(this), _value);
    }
}