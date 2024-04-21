// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {PoolVestingPeriod} from "./PoolVestingPeriod.sol";

/// @title Base contract for deposit, withdraw, borrow, repay behavior
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract PoolFunds is PoolVestingPeriod {
    using SafeERC20 for IERC20;

    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 public principalBalanceAmount;
    uint256 public principalOut;

    EnumerableMap.AddressToUintMap internal pendingWithdrawals;

    event Deposit(address indexed investor, uint256 amount);
    event Withdrawal(address indexed investor, address indexed receiver, uint256 amount);
    event PendingWithdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 amount);

    constructor(address _asset, string memory _tokenName, string memory _tokenSymbol)
    PoolVestingPeriod(_asset, _tokenName, _tokenSymbol) {}

    /*
    Investor flow
    */

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    /// @param _amount to deposit
    function deposit(uint256 _amount) public virtual {
        if (_amount < poolInfo.minInvestmentAmount) revert DepositAmountBelowMin();

        address holder = msg.sender;

        _updateEffectiveDepositDate(holder, _amount);

        _mint(holder, _amount);

        emit Deposit(holder, _amount);

        _depositAssetsFrom(holder, _amount);
    }

    /// @notice withdraws the caller's assets
    /// @param _amount to be withdrawn
    function withdraw(address _beneficiary, uint256 _amount) public virtual;

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _holder address of the recipient who didn't get the liquidity
    function concludePendingWithdrawal(address _holder) external nonReentrant onlyAdmin {
        uint256 amount = pendingWithdrawals.get(_holder);

        _burn(_holder, amount);

        //remove from pendingWithdrawals mapping
        pendingWithdrawals.remove(_holder);

        asset.safeTransferFrom(msg.sender, _holder, amount);

        emit PendingWithdrawalConcluded(_holder, amount);
    }

    /// @notice Borrow the pool's money for investment
    /// @param _to address for borrow funds
    /// @param _amount amount to be borrowed
    function borrow(address _to, uint256 _amount) public virtual notZero(_amount) onlyMultiSigAdmin {
        if (principalBalanceAmount < _amount) revert BorrowedMoreThanDeposited();
        principalOut += _amount;
        _transferAssets(_to, _amount);
    }

    /// @notice Repay asset without minimal threshold or getting LP in return
    /// @param _amount amount to be repaid
    function repay(uint256 _amount) public virtual notZero(_amount) onlyAdmin {
        if (_amount > principalOut) revert CantRepayMoreThanBorrowed();
        if (asset.balanceOf(msg.sender) < _amount) revert NotEnoughBalance();

        principalOut -= _amount;

        _depositAssetsFrom(msg.sender, _amount);
    }

    /*
    Helpers
    */

    /// @notice Get pending withdrawal for holder total deposited
    /// @param _holder address of holder
    function getPendingWithdrawalAmount(address _holder) external view returns (uint256) {
        (bool found, uint256 amount) = pendingWithdrawals.tryGet(_holder);
        return found ? amount : 0;
    }

    /// @notice Get pending withdrawal for holder total deposited
    function getPendingWithdrawalHolders() external view returns (address[] memory) {
        return pendingWithdrawals.keys();
    }

    /*
    Internals
    */

    /// @notice Transfers Pool assets to given `_to` address
    /// @param _to receiver's address
    /// @param _value amount to be transferred
    function _transferAssets(address _to, uint256 _value) internal {
        principalBalanceAmount -= _value;
        if (!asset.transfer(_to, _value)) revert TransferFailed();
    }

    /// @notice Transfer Pool assets from given `_from` address
    /// @param _from sender's address
    /// @param _value amount to be received
    function _depositAssetsFrom(address _from, uint256 _value) internal {
        principalBalanceAmount += _value;
        asset.safeTransferFrom(_from, address(this), _value);
    }
}