// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";

/// @title Base contract for Blended and Regional pools
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract AbstractPool is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PoolLibrary for PoolLibrary.DepositsStorage;

    string public constant NAME = "Helios Pool TKN";
    string public constant SYMBOL = "HLS-P";

    IERC20 public immutable asset; // The asset deposited by Lenders into the Pool
    IPoolFactory public immutable poolFactory; // The Pool factory that deployed this Pool

    PoolLibrary.DepositsStorage private depositsStorage;

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 minInvestmentAmount;
        uint256 investmentPoolSize;
    }

    PoolInfo public poolInfo;

    uint256 public totalDeposited;
    uint256 public principalOut;

    mapping(address => uint256) public yields;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public pendingYields;

    event Deposit(address indexed investor, uint256 amount);
    event Withdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 amount);
    event YieldWithdrawn(address indexed recipient, uint256 amount);
    event PendingYield(address indexed recipient, uint256 amount);
    event PendingYieldConcluded(address indexed recipient, uint256 amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 amount);
    event BalanceUpdated(address indexed pool, address indexed token, uint256 balance);

    constructor(address _asset, string memory _tokenName, string memory _tokenSymbol)
    ERC20(_tokenName, _tokenSymbol) {
        require(_asset != address(0), "P:ZERO_LIQ_ASSET");

        poolFactory = IPoolFactory(msg.sender);
        require(poolFactory.globals().isValidAsset(_asset), "P:INVALID_LIQ_ASSET");

        asset = IERC20(_asset);
    }

    /*
    Investor flow
    */

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    /// @param _amount to deposit
    function deposit(uint256 _amount) external virtual;

    /// @notice withdraws the caller's assets
    /// @param _amount to be withdrawn
    function withdraw(uint256 _amount) public virtual;

    /// @notice check how much funds already unlocked
    /// @param _holder to be checked
    function unlockedBalanceOf(address _holder) public view returns (uint256) {
        return balanceOf(_holder) - depositsStorage.lockedDepositsAmount(_holder);
    }

    /// @notice Used to transfer the investor's yields to him
    function withdrawYield() external virtual nonReentrant whenProtocolNotPaused returns (bool) {
        require(yields[msg.sender] > 0, "P:ZERO_YIELD");

        uint256 callerYields = yields[msg.sender];
        yields[msg.sender] = 0;

        if (totalBalance() < callerYields) {
            pendingYields[msg.sender] += callerYields;
            emit PendingYield(msg.sender, callerYields);
            return false;
        }

        _transferFunds(msg.sender, callerYields);

        emit YieldWithdrawn(msg.sender, callerYields);
        return true;
    }

    /// @notice Used to distribute yields among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    function distributeYields(uint256 _amount) external virtual onlyAdmin nonReentrant {
        require(_amount > 0, "P:INVALID_VALUE");

        uint256 count = depositsStorage.getHoldersCount();
        for (uint256 i = 0; i < count; i++) {
            address holder = depositsStorage.getHolderByIndex(i);
            yields[holder] += _calculateYield(holder, _amount);
        }
    }

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _holder address of the recipient who didn't get the liquidity
    function concludePendingWithdrawal(address _holder) external nonReentrant onlyAdmin {
        uint256 amount = pendingWithdrawals[_holder];

        _burn(_holder, amount);

        //remove from pendingWithdrawals mapping
        delete pendingWithdrawals[_holder];

        asset.safeTransferFrom(msg.sender, _holder, amount);

        emit PendingWithdrawalConcluded(_holder, amount);
    }

    /// @notice Admin function used for unhappy path after yield withdraw failure
    /// @param _holder address of the recipient who didn't get the yield
    function concludePendingYield(address _holder) external nonReentrant onlyAdmin {
        uint256 amount = pendingYields[_holder];

        //remove from pendingWithdrawals mapping:
        delete pendingYields[_holder];

        _transferFunds(_holder, amount);

        emit PendingYieldConcluded(_holder, amount);
    }

    /// @notice Borrow the pool's money for investment
    /// @param _to address for borrow funds
    /// @param _amount amount to be borrowed
    function borrow(address _to, uint256 _amount) external nonReentrant onlyAdmin {
        principalOut += _amount;
        _transferFunds(_to, _amount);
    }

    /// @notice Repay asset without minimal threshold or getting LP in return
    /// @param _amount amount to be repaid
    function repay(uint256 _amount) external nonReentrant onlyAdmin {
        require(asset.balanceOf(msg.sender) >= _amount, "P:NOT_ENOUGH_BALANCE");
        if (_amount >= principalOut) {
            principalOut = 0;
        } else {
            principalOut -= _amount;
        }

        asset.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /*
    ERC20 Overrides
    */

    function transfer(address _to, uint256 _value) public override returns (bool) {
        address owner = _msgSender();
        require(unlockedBalanceOf(owner) >= _value, "P:TOKENS_LOCKED");

        _transfer(owner, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        address spender = _msgSender();
        require(unlockedBalanceOf(_from) >= _value, "P:TOKENS_LOCKED");

        _spendAllowance(_from, spender, _value);
        _transfer(_from, _to, _value);
        return true;
    }

    /*
    Helpers
    */

    /// @notice Get Deposit Holder's address
    /// @param _index index for holder
    function getHolderByIndex(uint256 _index) external view returns (address) {
        return depositsStorage.getHolderByIndex(_index);
    }

    /// @notice Get holders Count
    function getHoldersCount() external view returns (uint256) {
        return depositsStorage.getHoldersCount();
    }

    /// @notice Get the amount of assets in the pool
    function totalBalance() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @notice Get asset's decimals
    function decimals() public view override returns (uint8) {
        return ERC20(address(asset)).decimals();
    }

    /// @notice Get pool general info
    function getPoolInfo() public view returns (PoolInfo memory) {
        return poolInfo;
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

    /// @notice Shared deposit logic
    /// @param _amount to be deposited
    /// @param _holder holders address
    function _depositLogic(uint256 _amount, address _holder) internal {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");

        depositsStorage.addDeposit(_holder, _amount, block.timestamp + poolInfo.lockupPeriod);

        _mintAndUpdateTotalDeposited(_holder, _amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(_holder, _amount);

        asset.safeTransferFrom(_holder, address(this), _amount);
    }

    /// @notice Mint Pool assets to given `_account` address and update totalDeposited
    /// @param _account holder's address
    /// @param _amount to be minted
    function _mintAndUpdateTotalDeposited(address _account, uint256 _amount) internal {
        _mint(_account, _amount);
        totalDeposited += _amount;
    }

    /// @notice Transfers Pool assets to given `_to` address
    /// @param _to receiver's address
    /// @param _value amount to be transferred
    function _transferFunds(address _to, uint256 _value) internal {
        require(asset.transfer(_to, _value), "P:TRANSFER_FAILED");
    }

    /// @notice Emits a `BalanceUpdated` event for Pool
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(address(this), address(this), totalBalance());
    }

    /*
    Modifiers
    */

    /// @notice Checks that the protocol is not in a paused state
    modifier whenProtocolNotPaused() {
        require(!poolFactory.globals().protocolPaused(), "P:PROTO_PAUSED");
        _;
    }

    /// @notice Checks that the admin call
    modifier onlyAdmin() {
        require(poolFactory.globals().isAdmin(msg.sender), "PF:NOT_ADMIN");
        _;
    }
}