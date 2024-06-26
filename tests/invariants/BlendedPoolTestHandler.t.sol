pragma solidity 0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";

contract BlendedPoolTestHandler is CommonBase, StdCheats, StdUtils {
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;

    BlendedPool public blendedPool;
    Pool public pool;
    MockTokenERC20 public assetElevated;
    ERC20 public asset;

    address[] public USER_ADDRESSES = [
    address(uint160(uint256(keccak256("user1")))),
    address(uint160(uint256(keccak256("user2")))),
    address(uint160(uint256(keccak256("user3")))),
    address(uint160(uint256(keccak256("user4")))),
    address(uint160(uint256(keccak256("user5"))))
    ];

    constructor(BlendedPool _blendedPool, Pool _pool, MockTokenERC20 _assetElevated){
        blendedPool = _blendedPool;
        pool = _pool;
        assetElevated = _assetElevated;
        asset = ERC20(assetElevated);
    }

    uint256 public totalInvested;
    uint256 public totalWithdrawn;
    uint256 public totalYieldAccrued;
    uint256 public totalYieldWithdrawn;
    uint256 public totalYieldPrecisionLoss;
    uint256 public totalBorrowed;
    uint256 public totalRepaid;
    uint256 public totalInvestedToRegionalPool;
    uint256 public totalYieldsFromRegionalPool;
    uint256 public maxPrecisionLossForYields;

    /// Make a deposit for a user
    function deposit(uint256 amount, uint256 user_idx) public virtual {
        address user = pickUpUser(user_idx);

        amount = bound(amount, 1, type(uint80).max);

        if (asset.balanceOf(user) < amount) {
            assetElevated.mint(user, amount);
        }

        vm.prank(user);
        asset.approve(address(blendedPool), amount);
        vm.prank(user);
        blendedPool.deposit(amount);

        totalInvested += amount;
    }

    /// Withdraw deposit for a user
    function withdraw(uint256 amount, uint256 user_idx) external {
        address user = pickUpUserFromBlendedPool(user_idx);
        if (user == address(0)) return;

        vm.prank(user);
        uint256 unlocked = blendedPool.unlockedToWithdraw(user);
        if (unlocked == 0) return;

        unlocked = bound(amount, 1, unlocked);

        vm.prank(user);
        blendedPool.withdraw(user, unlocked);

        totalWithdrawn += amount;
    }

    /// Withdraw yield for a user
    function withdrawYield(uint256 user_idx) external {
        address user = pickUpUser(user_idx);

        if (totalYieldAccrued == 0) return;

        uint256 user_current_yield = blendedPool.yields(user);

        if (user_current_yield == 0) return;

        vm.prank(user);
        if (blendedPool.withdrawYield(user)) {
            // withdrawn
            totalYieldAccrued -= user_current_yield;
            totalYieldWithdrawn += user_current_yield;
        }
    }

    /*
    HANDLERS - Admin Workflow
    */

    /// Distribute yields
    function repayYield() external {
        if (blendedPool.getHoldersCount() == 0) return;

        uint256 startingSumYields = sumUserYields();

        uint256 newYieldToDistribute = 0.1e18;
        assetElevated.mint(OWNER_ADDRESS, newYieldToDistribute);

        vm.prank(OWNER_ADDRESS);
        asset.approve(address(blendedPool), newYieldToDistribute);

        vm.prank(OWNER_ADDRESS);
        blendedPool.repayYield(newYieldToDistribute);

        totalRepaid += newYieldToDistribute;
        totalYieldAccrued += newYieldToDistribute;

        uint256 actualChangeInUserYields = sumUserYields() - startingSumYields;

        totalYieldPrecisionLoss += newYieldToDistribute - actualChangeInUserYields;

        // The maximum precision loss for this distribution is the total number of depositors minus 1
        // example: if there are 50 depositors and the distribution is 100049, there is a precision loss of 49
        if (blendedPool.getHoldersCount() > 0)
            maxPrecisionLossForYields += blendedPool.getHoldersCount() - 1;
    }

    /// Finish pending withdrawal for a user
    function concludePendingWithdrawal(uint256 user_idx) external {
        address user = pickUpUser(user_idx);

        uint256 pendingWithdrawalAmount = blendedPool.getPendingWithdrawalAmount(user);

        if (pendingWithdrawalAmount > 0)
        {
            vm.prank(OWNER_ADDRESS);
            blendedPool.concludePendingWithdrawal(user);

            totalWithdrawn += pendingWithdrawalAmount;
        }
    }

    /// Borrow money from the deposits
    function borrow(uint256 amount) external {
        if (blendedPool.principalBalanceAmount() == 0) return;

        amount = bound(amount, 1, blendedPool.principalBalanceAmount());

        vm.prank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, amount);

        totalBorrowed += amount;
    }

    /// Repay money to the pool
    function repay(uint256 amount) external {
        if (blendedPool.principalOut() == 0) return;

        amount = bound(amount, 1, blendedPool.principalOut());

        assetElevated.mint(OWNER_ADDRESS, amount);

        vm.prank(OWNER_ADDRESS);
        asset.approve(address(blendedPool), amount);

        vm.prank(OWNER_ADDRESS);
        blendedPool.repay(amount);

        totalRepaid += amount;
    }

    function depositToPool(uint256 amount) public virtual {
        if (blendedPool.principalBalanceAmount() > 1)
        {
            uint maxDepositAmount = Math.min(blendedPool.principalBalanceAmount(), type(uint80).max);
            amount = bound(amount, 1, maxDepositAmount);

            vm.prank(OWNER_ADDRESS);
            blendedPool.depositToOpenPool(address(pool), amount);

            totalInvestedToRegionalPool += amount;
        }
    }

    function withdrawFromPool() public virtual {
        uint256 amount = pool.balanceOf(address(blendedPool));
        if (amount > 0)
        {
            warp(pool.getHolderUnlockDate(address(blendedPool)));
            vm.prank(OWNER_ADDRESS);
            blendedPool.withdrawFromPool(address(pool), amount);

            totalInvestedToRegionalPool -= amount;
        }
    }

    function withdrawYieldFromPool() public virtual {
        uint256 amount = pool.yields(address(blendedPool));
        if (amount > 0)
        {
            vm.prank(OWNER_ADDRESS);
            blendedPool.withdrawYieldFromPool(address(pool));
            totalYieldsFromRegionalPool += amount;
        }
    }

    function repayRegionalPool(uint256 amount) public virtual {
        amount = bound(amount, 1, type(uint80).max);
        if (amount > 0)
        {
            assetElevated.mint(OWNER_ADDRESS, amount);

            vm.prank(OWNER_ADDRESS);
            asset.approve(address(pool), amount);

            vm.prank(OWNER_ADDRESS);
            pool.repayYield(amount);
        }
    }

    /// Time warp simulation
    function warp(uint256 timestamp) public virtual {
        timestamp = bound(timestamp, 500, type(uint80).max);
        vm.warp(block.timestamp + timestamp);
    }

    function users() public view returns (address[] memory) {
        return USER_ADDRESSES;
    }

    function sumUserYields() public view returns (uint sum){
        sum = 0;
        for (uint i = 0; i < blendedPool.getHoldersCount(); i++) {
            address holder = blendedPool.getHolderByIndex(i);
            sum += blendedPool.yields(holder);
        }
    }

    function sumUserLockedTokens() public view returns (uint sum){
        sum = 0;
        for (uint i = 0; i < blendedPool.getHoldersCount(); i++) {
            address holder = blendedPool.getHolderByIndex(i);
            sum += blendedPool.balanceOf(holder) - blendedPool.unlockedToWithdraw(holder);
        }
    }

    function pickUpUser(uint256 user_idx) public view returns (address) {
        user_idx = user_idx % USER_ADDRESSES.length;
        return USER_ADDRESSES[user_idx];
    }

    function pickUpUserFromBlendedPool(uint256 user_idx) public view returns (address) {
        uint256 holderCount = blendedPool.getHoldersCount();
        if (holderCount == 0) return address(0);

        user_idx = bound(user_idx, 0, holderCount - 1);

        return blendedPool.getHolderByIndex(user_idx);
    }
}