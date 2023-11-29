// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../interfaces/IPoolFactory.sol";

import "../interfaces/IHeliosGlobals.sol";
import "../library/PoolLib.sol";
import "../token/PoolFDT.sol";
import "./AbstractPool.sol";

/// @title Blended Pool
contract BlendedPool is AbstractPool {
    using SafeMathUint for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool

    uint256 public principalOut; // The sum of all outstanding principal on Loans. TODO ??
    address public borrower; // Address of borrower for this Pool.
    mapping(address => bool) public pools;

    event RegPoolDeposit(address indexed regPool, uint256 amount);


    constructor(
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount
    ) AbstractPool(_liquidityAsset, _llFactory, PoolLib.NAME, PoolLib.SYMBOL) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");

        superFactory = msg.sender;

        poolInfo = PoolInfo(
            _lockupPeriod,
            _apy,
            _duration,
            type(uint256).max,
            _minInvestmentAmount
        );
    }

    function withdrawableOf(address _holder) external view returns (uint256) {
        require(
            depositDate[_holder] + poolInfo.lockupPeriod <= block.timestamp,
            "P:FUNDS_LOCKED"
        );

        return
            Math.min(
                liquidityAsset.balanceOf(address(liquidityLocker)),
                super.balanceOf(_holder)
            );
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
        require(callerRewards >= 0, "P:NOT_HOLDER");
        uint256 totalBalance = liquidityLocker.totalBalance();
        rewards[msg.sender] = 0;

        if (totalBalance < callerRewards) {
            pendingRewards[msg.sender] += callerRewards;
            emit PendingReward(msg.sender, callerRewards);
            return false;
        }

        require(
            _transferLiquidityLockerFunds(msg.sender, callerRewards),
            "P:ERROR_TRANSFERRING_REWARD"
        );

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    /// @notice Only called by a RegPool when it doesn't have enough LA
    function requestLiquidityAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "P:INVALID_INPUT");
        require(totalSupplyLA() >= _amountMissing, "P:NOT_ENOUGH_LA_BP");
        require(
            liquidityLocker.transfer(msg.sender, _amountMissing),
            "P:REQUEST_FROM_BP_FAIL"
        );
        emit RegPoolDeposit(msg.sender, _amountMissing);
    }

    /// @notice Get the amount of Liquidity Assets in the Blended Pool
    function totalSupplyLA() public view returns (uint256) {
        return liquidityLocker.totalBalance();
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
