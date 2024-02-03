// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {AbstractPool} from "./AbstractPool.sol";
import {ILiquidityLocker} from "../interfaces/ILiquidityLocker.sol";
import {ILiquidityLockerFactory} from "../interfaces/ILiquidityLockerFactory.sol";

/// @title Blended Pool
contract BlendedPool is AbstractPool {
    using SafeERC20 for IERC20;

    address public borrower; // Address of borrower for this Pool.
    mapping(address => bool) public pools;

    event RegPoolDeposit(address indexed regPool, uint256 amount);

    constructor(
        address _liquidityAsset,
        address _liquidityLockerFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_liquidityAsset, _liquidityLockerFactory, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        require(_liquidityAsset != address(0), "BP:ZERO_LIQ_ASSET");
        require(_liquidityLockerFactory != address(0), "BP:ZERO_LIQ_LOCKER_FACTORY");

        require(_globals(superFactory).isValidLiquidityAsset(_liquidityAsset), "BP:INVALID_LIQ_ASSET");
        require(_globals(superFactory).isValidLiquidityLockerFactory(_liquidityLockerFactory), "BP:INVALID_LL_FACTORY");

        poolInfo = PoolInfo(_lockupPeriod, _apy, _duration, type(uint256).max, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice Used to distribute rewards among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list of investors must be provided externally due to Solidity limitations
    function distributeRewards(uint256 _amount, address[] calldata _holders) external override onlyAdmin nonReentrant {
        require(_amount > 0, "BP:INVALID_VALUE");
        require(_holders.length > 0, "BP:ZERO_HOLDERS");
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (_amount * holderBalance) / totalSupply();
            rewards[holder] += holderShare;
        }
    }

    function withdrawableOf(address _holder) external view returns (uint256) {
        require(depositDate[_holder] + poolInfo.lockupPeriod <= block.timestamp, "BP:FUNDS_LOCKED");

        return Math.min(liquidityAsset.balanceOf(address(liquidityLocker)), super.balanceOf(_holder));
    }

    function totalLA() external view returns (uint256) {
        return liquidityLocker.totalBalance();
    }

    function totalDeposited() external view returns (uint256) {
        return totalMinted;
    }

    function decimals() public view override returns (uint8) {
        return uint8(liquidityAssetDecimals);
    }

    /// @notice Used to transfer the investor's rewards to him
    function claimReward() external override returns (bool) {
        uint256 callerRewards = rewards[msg.sender];
        uint256 totalBalance = liquidityLocker.totalBalance();
        rewards[msg.sender] = 0;

        if (totalBalance < callerRewards) {
            pendingRewards[msg.sender] += callerRewards;
            emit PendingReward(msg.sender, callerRewards);
            return false;
        }

        require(_transferLiquidityLockerFunds(msg.sender, callerRewards), "BP:ERROR_TRANSFERRING_REWARD");

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    /// @notice Only called by a RegPool when it doesn't have enough LA
    function requestLiquidityAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "BP:INVALID_INPUT");
        require(totalSupplyLA() >= _amountMissing, "BP:NOT_ENOUGH_LA_BP");
        address poolLL = AbstractPool(msg.sender).getLL();
        require(_transferLiquidityLockerFunds(poolLL, _amountMissing), "BP:REQUEST_FROM_BP_FAIL");

        emit RegPoolDeposit(msg.sender, _amountMissing);
    }

    /// @notice Get the amount of Liquidity Assets in the Blended Pool
    function totalSupplyLA() public view returns (uint256) {
        return liquidityLocker.totalBalance();
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenNotPaused nonReentrant {
        require(_amount >= poolInfo.minInvestmentAmount, "BP:DEP_AMT_BELOW_MIN");

        IERC20 mainLA = liquidityLocker.liquidityAsset();

        depositLogic(_amount, mainLA);
    }

    /// @notice Register a new pool to the Blended Pool
    function addPool(address _pool) external onlyAdmin {
        pools[_pool] = true;
    }

    /// @notice Register new pools in batch to the Blended Pool
    function addPools(address[] memory _pools) external onlyAdmin {
        for (uint256 i = 0; i < _pools.length; i++) {
            pools[_pools[i]] = true;
        }
    }

    /// @notice Remove a pool when it's no longer actual
    function removePool(address _pool) external onlyAdmin {
        delete pools[_pool];
    }

    // Returns the LiquidityLocker instance
    function _liquidityLocker() internal view returns (ILiquidityLocker) {
        return ILiquidityLocker(liquidityLocker);
    }

    function _globals(address poolFactory) internal override view returns (IHeliosGlobals) {
        return IHeliosGlobals(IPoolFactory(poolFactory).globals());
    }

    modifier onlyPool() {
        require(pools[msg.sender], "P:NOT_POOL");
        _;
    }
}
