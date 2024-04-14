// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pool} from "./Pool.sol";
import {PoolYieldDistribution} from "./base/PoolYieldDistribution.sol";

/// @title Blended Pool implementation
/// @author Tigran Arakelyan
contract BlendedPool is PoolYieldDistribution {
    using EnumerableSet for EnumerableSet.AddressSet;

    event RegPoolDeposited(address indexed regPool, uint256 amount);

    EnumerableSet.AddressSet private pools;

    constructor(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount,
        string memory _tokenName,
        string memory _tokenSymbol)
    PoolYieldDistribution(_asset, _tokenName, _tokenSymbol) {
        poolInfo = PoolInfo(_lockupPeriod, _minInvestmentAmount, type(uint256).max);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    /// @param _amount the amount of assets to be deposited
    function deposit(uint256 _amount) public override notZero(_amount) whenProtocolNotPaused nonReentrant {
        super.deposit(_amount);
    }

    /// @notice withdraws the caller's liquidity assets
    /// @param _amount to be withdrawn
    function withdraw(address _beneficiary, uint256 _amount) public override unlocked(msg.sender) nonReentrant whenProtocolNotPaused {
        if (balanceOf(msg.sender) < _amount) revert InsufficientFunds();
        if (principalBalanceAmount < _amount) revert NotEnoughAssets();

        _burn(msg.sender, _amount);

        emit BalanceUpdated(address(this), address(this), totalBalance());
        emit Withdrawal(msg.sender, _beneficiary, _amount);

        _transferAssets(_beneficiary, _amount);
    }

    function borrow(address _to, uint256 _amount) public override nonReentrant {
        super.borrow(_to, _amount);
    }

    function repay(uint256 _amount) public override nonReentrant {
        super.repay(_amount);
    }

    /// @notice Only called by a RegPool when it doesn't have enough Assets
    /// @param _amount the amount requested for compensation
    function depositToClosedPool(uint256 _amount) external notZero(_amount) nonReentrant onlyPool {
        if (principalBalanceAmount < _amount) revert NotEnoughAssets();

        Pool pool = Pool(msg.sender);
        bool success = asset.approve(address(pool), _amount);

        if (success)
        {
            pools.add(address(pool));
            principalBalanceAmount -= _amount;
            emit RegPoolDeposited(msg.sender, _amount);
            pool.blendedPoolDeposit(_amount);
        }
    }

    function depositToOpenPool(address _poolAddress, uint256 _amount) public onlyAdmin nonReentrant whenProtocolNotPaused {
        if (principalBalanceAmount < _amount) revert NotEnoughAssets();

        Pool pool = Pool(_poolAddress);
        bool success = asset.approve(_poolAddress, _amount);
        if (success)
        {
            pools.add(address(pool));
            principalBalanceAmount -= _amount;
            emit RegPoolDeposited(address(pool), _amount);
            pool.deposit(_amount);
        }
    }

    function withdrawFromPool(address _poolAddress, uint256 _amount) public onlyAdmin nonReentrant whenProtocolNotPaused {
        Pool pool = Pool(_poolAddress);
        principalBalanceAmount += _amount;
        pool.withdraw(address(this), _amount);
    }

    function withdrawYieldFromPool(address _poolAddress) public onlyAdmin nonReentrant whenProtocolNotPaused {
        Pool pool = Pool(_poolAddress);
        principalBalanceAmount += pool.yields(address(this));
        pool.withdrawYield(address(this));
    }

    function investedPools() public view returns (address[] memory) {
        return pools.values();
    }

    /// @notice Only pool can call
    modifier onlyPool() {
        if (poolFactory.isValidPool(msg.sender) == false) revert NotPool();
        _;
    }
}
