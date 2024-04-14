// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolVestingPeriod} from "./PoolVestingPeriod.sol";

/// @title Base contract for Blended and Regional pools
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract AbstractPool is PoolVestingPeriod {
    using SafeERC20 for IERC20;

    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 public principalBalanceAmount;
    uint256 public yieldBalanceAmount;
    uint256 public principalOut;

    mapping(address => uint256) public yields;
    EnumerableMap.AddressToUintMap internal pendingWithdrawals;

    event Deposit(address indexed investor, uint256 amount);
    event Withdrawal(address indexed investor, address indexed receiver, uint256 amount);
    event PendingWithdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 amount);
    event YieldWithdrawn(address indexed investor, address indexed receiver, uint256 amount);
    event BalanceUpdated(address indexed pool, address indexed token, uint256 balance);

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

        _addInvestment(holder, _amount, block.timestamp + poolInfo.lockupPeriod);

        _mint(holder, _amount);

        emit BalanceUpdated(address(this), address(this), totalBalance());
        emit Deposit(holder, _amount);

        _depositAssetsFrom(holder, _amount);
    }

    /// @notice withdraws the caller's assets
    /// @param _amount to be withdrawn
    function withdraw(address _beneficiary, uint256 _amount) public virtual;

    /// @notice Used to transfer the investor's yields to him
    function withdrawYield(address _beneficiary) external virtual nonReentrant whenProtocolNotPaused returns (bool) {
        return _withdrawYield(msg.sender, _beneficiary);
    }

    /// @notice Used to transfer the investor's yields to reinvest
    function withdrawYield(address _holder, address _beneficiary) external virtual onlyAdmin nonReentrant whenProtocolNotPaused returns (bool) {
        return _withdrawYield(_holder, _beneficiary);
    }

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
    function borrow(address _to, uint256 _amount) public virtual notZero(_amount) onlyAdmin {
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
    Helpers
    */

    /// @notice Get pending withdrawal for holder total deposited
    /// @param _holder address of holder
    function getPendingWithdrawalAmount(address _holder) external view returns (uint256) {
        return pendingWithdrawals.get(_holder);
    }

    /// @notice Get pending withdrawal for holder total deposited
    function getPendingWithdrawalHolders() external view returns (address[] memory) {
        return pendingWithdrawals.keys();
    }

    /*
    Internals
    */

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

    /// @notice Transfers Pool assets to given `_to` address
    /// @param _to receiver's address
    /// @param _value amount to be transferred
    function _transferAssets(address _to, uint256 _value) internal {
        principalBalanceAmount -= _value;
        if (asset.transfer(_to, _value) == false) revert TransferFailed();
    }

    /// @notice Transfer Pool assets from given `_from` address
    /// @param _from sender's address
    /// @param _value amount to be received
    function _depositAssetsFrom(address _from, uint256 _value) internal {
        principalBalanceAmount += _value;
        asset.safeTransferFrom(_from, address(this), _value);
    }

    /// @notice Transfers yield assets to given `_to` address
    /// @param _to receiver's address
    /// @param _value amount to be transferred
    function _transferYields(address _to, uint256 _value) internal {
        yieldBalanceAmount -= _value;
        if (asset.transfer(_to, _value) == false) revert TransferFailed();
    }

    /// @notice Deposit yield assets from given `_from` address
    /// @param _from sender's address
    /// @param _value amount to be received
    function _depositYieldsFrom(address _from, uint256 _value) internal {
        yieldBalanceAmount += _value;
        asset.safeTransferFrom(_from, address(this), _value);
    }
}