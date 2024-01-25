// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../interfaces/IPoolFactory.sol";

import "../interfaces/IHeliosGlobals.sol";
import "./AbstractPool.sol";

/// @title Blended Pool
contract BlendedPool is AbstractPool {
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool

    address public borrower; // Address of borrower for this Pool.
    mapping(address => bool) public pools;

    event RegPoolDeposit(address indexed regPool, uint256 amount);

    constructor(
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_liquidityAsset, _llFactory, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");

        superFactory = msg.sender;

        poolInfo = PoolInfo(_lockupPeriod, _apy, _duration, type(uint256).max, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice Used to distribute rewards among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list of investors must be provided externally due to Solidity limitations
    function distributeRewards(uint256 _amount, address[] calldata _holders) external override onlyOwner nonReentrant {
        require(_amount > 0, "P:INVALID_VALUE");
        require(_holders.length > 0, "P:ZERO_HOLDERS");
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (_amount * holderBalance) / totalSupply();
            rewards[holder] += holderShare;
        }
    }

    function withdrawableOf(address _holder) external view returns (uint256) {
        require(depositDate[_holder] + poolInfo.lockupPeriod <= block.timestamp, "P:FUNDS_LOCKED");

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

        require(_transferLiquidityLockerFunds(msg.sender, callerRewards), "P:ERROR_TRANSFERRING_REWARD");

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    /// @notice Only called by a RegPool when it doesn't have enough LA
    function requestLiquidityAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "P:INVALID_INPUT");
        require(totalSupplyLA() >= _amountMissing, "P:NOT_ENOUGH_LA_BP");
        address poolLL = AbstractPool(msg.sender).getLL();
        require(_transferLiquidityLockerFunds(poolLL, _amountMissing), "P:REQUEST_FROM_BP_FAIL");

        emit RegPoolDeposit(msg.sender, _amountMissing);
    }

    /// @notice Get the amount of Liquidity Assets in the Blended Pool
    function totalSupplyLA() public view returns (uint256) {
        return liquidityLocker.totalBalance();
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenNotPaused nonReentrant {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");

        IERC20 mainLA = liquidityLocker.liquidityAsset();

        depositLogic(_amount, mainLA);
    }

    /// @notice Register a new pool to the Blended Pool
    function addPool(address _pool) external onlyOwner {
        pools[_pool] = true;
    }

    /// @notice Register new pools in batch to the Blended Pool
    function addPools(address[] memory _pools) external onlyOwner {
        for (uint256 i = 0; i < _pools.length; i++) {
            pools[_pools[i]] = true;
        }
    }

    /// @notice Remove a pool when it's no longer actual
    function removePool(address _pool) external onlyOwner {
        delete pools[_pool];
    }

    // Returns the LiquidityLocker instance
    function _liquidityLocker() internal view returns (ILiquidityLocker) {
        return ILiquidityLocker(liquidityLocker);
    }

    modifier onlyPool() {
        require(pools[msg.sender], "P:NOT_POOL");
        _;
    }
}
