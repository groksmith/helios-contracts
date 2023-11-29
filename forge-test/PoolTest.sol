pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {MockERC20} from "./MockERC20.sol";
import "../contracts/pool/AbstractPool.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import "../contracts/pool/BlendedPool.sol";

import {FixtureContract} from "./FixtureContract.sol";

contract BlendedPoolTest is Test, FixtureContract {
    event PendingReward(address indexed recipient, uint256 amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 amount);

    function setUp() public {
        fixture();
        vm.prank(OWNER_ADDRESS);
        liquidityAsset.increaseAllowance(address(blendedPool), 1000);
        vm.prank(ADMIN_ADDRESS);
        liquidityAsset.increaseAllowance(address(blendedPool), 1000);
    }

    /// @notice Test attempt to deposit; checking if variables are updated correctly
    function test_depositSuccess() external {
        vm.startPrank(OWNER_ADDRESS);

        //testing initial condition i.e. zeroes
        assertEq(blendedPool.balanceOf(OWNER_ADDRESS), 0);
        assertEq(blendedPool.totalLA(), 0);
        assertEq(blendedPool.totalDeposited(), 0);

        uint user1Deposit = 100;
        blendedPool.deposit(user1Deposit);

        //user's LP balance should be 100 now
        assertEq(
            blendedPool.balanceOf(OWNER_ADDRESS),
            user1Deposit,
            "wrong LP balance for user1"
        );

        //pool's total LA balance should be user1Deposit now
        assertEq(
            blendedPool.totalLA(),
            user1Deposit,
            "wrong LA balance after user1 deposit"
        );

        //pool's total minted should also be user1Deposit
        assertEq(
            blendedPool.totalDeposited(),
            user1Deposit,
            "wrong totalDeposit after user1 deposit"
        );
        vm.stopPrank();

        //now let's test for user2
        vm.startPrank(ADMIN_ADDRESS);
        assertEq(
            blendedPool.balanceOf(ADMIN_ADDRESS),
            0,
            "user2 shouldn't have >0 atm"
        );
        uint user2Deposit = 101;

        blendedPool.deposit(user2Deposit);

        assertEq(
            blendedPool.balanceOf(ADMIN_ADDRESS),
            user2Deposit,
            "wrong user2 LP balance"
        );

        //pool's total LA balance should be user1Deposit now
        assertEq(
            blendedPool.totalLA(),
            user1Deposit + user2Deposit,
            "wrong totalLA after user2"
        );

        //pool's total minted should also be user1Deposit
        assertEq(
            blendedPool.totalDeposited(),
            user1Deposit + user2Deposit,
            "wrong totalDeposited after user2"
        );
        vm.stopPrank();
    }

    /// @notice Test attempt to deposit below minimum
    function test_depositFailure() external {
        vm.startPrank(OWNER_ADDRESS);
        uint depositAmountBelowMin = 1;
        vm.expectRevert("P:DEP_AMT_BELOW_MIN");
        blendedPool.deposit(depositAmountBelowMin);
    }

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function test_withdraw() external {
        vm.startPrank(ADMIN_ADDRESS);
        uint depositAmount = 150;
        uint currentTime = block.timestamp;

        //the user can withdraw the sum he has deposited earlier
        blendedPool.deposit(depositAmount);

        //attempt to withdraw too early fails
        vm.expectRevert("P:FUNDS_LOCKED");
        blendedPool.withdraw(depositAmount);

        vm.warp(currentTime + 1000);
        blendedPool.withdraw(depositAmount);

        //but he cannot withdraw more
        vm.expectRevert("P:INSUFFICIENT_BALANCE");
        blendedPool.withdraw(1);

        vm.stopPrank();
    }

    /// @notice Test complete scenario of depositing, distribution of rewards and claim
    function test_distributeRewardsAndClaim() external {
        //firstly the users need to deposit before withdrawing
        uint user1Deposit = 100;
        vm.prank(OWNER_ADDRESS);
        blendedPool.deposit(user1Deposit);

        uint user2Deposit = 1000;
        vm.prank(ADMIN_ADDRESS);
        blendedPool.deposit(user2Deposit);

        address[] memory holders = new address[](2);
        holders[0] = OWNER_ADDRESS;
        holders[1] = ADMIN_ADDRESS;

        //a non-pool-admin address shouldn't be able to call distributeRewards()
        vm.prank(OWNER_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");
        blendedPool.distributeRewards(1000, holders);

        //only the pool admin can call distributeRewards()
        address poolAdmin = blendedPool.owner();
        vm.prank(poolAdmin);
        blendedPool.distributeRewards(1000, holders);

        //now we need to test if the users got assigned the correct rewards
        uint user1Rewards = blendedPool.rewards(OWNER_ADDRESS);
        uint user2Rewards = blendedPool.rewards(ADMIN_ADDRESS);
        assertEq(user1Rewards, 90, "wrong reward user1");
        assertEq(user2Rewards, 909, "wrong reward user2"); //NOTE: 1 is lost as a dust value :(

        uint user1BalanceBefore = liquidityAsset.balanceOf(OWNER_ADDRESS);
        vm.prank(OWNER_ADDRESS);
        blendedPool.claimReward();
        assertEq(
            liquidityAsset.balanceOf(OWNER_ADDRESS) - user1BalanceBefore,
            90,
            "user1 balance not upd after claimReward()"
        );

        uint user2BalanceBefore = liquidityAsset.balanceOf(ADMIN_ADDRESS);
        vm.prank(ADMIN_ADDRESS);
        blendedPool.claimReward();
        assertEq(
            liquidityAsset.balanceOf(ADMIN_ADDRESS) - user2BalanceBefore,
            909,
            "user2 balance not upd after claimReward()"
        );
    }

    /// @notice Test scenario when there are not enough funds on the pool
    function test_insufficientFundsClaimReward() external {
        //firstly the users need to deposit before withdrawing
        uint user1Deposit = 100;
        vm.prank(OWNER_ADDRESS);
        blendedPool.deposit(user1Deposit);

        address[] memory holders = new address[](1);
        holders[0] = OWNER_ADDRESS;

        //only the pool admin can call distributeRewards()
        address poolAdmin = blendedPool.owner();
        vm.prank(poolAdmin);
        blendedPool.distributeRewards(1000, holders);

        assertEq(
            blendedPool.rewards(OWNER_ADDRESS),
            1000,
            "rewards should be 1000 atm"
        );

        //now let's deplete the pool's balance
        vm.prank(poolAdmin);
        blendedPool.adminWithdraw(poolAdmin, 100);

        //..and claim rewards as user1
        vm.prank(OWNER_ADDRESS);
        vm.expectEmit(true, true, false, false);
        // The expected event signature
        emit PendingReward(OWNER_ADDRESS, 1000);
        assertFalse(
            blendedPool.claimReward(),
            "should return false if not enough LA"
        );

        assertEq(
            blendedPool.rewards(OWNER_ADDRESS),
            0,
            "rewards should be 0 after claim attempt"
        );

        assertEq(
            blendedPool.pendingRewards(OWNER_ADDRESS),
            1000,
            "pending rewards should be 1000 after claim attempt"
        );

        uint user1BalanceBefore = liquidityAsset.balanceOf(OWNER_ADDRESS);

        liquidityAssetElevated.mint(poolAdmin, 1000);
        vm.startPrank(poolAdmin);
        liquidityAsset.increaseAllowance(address(blendedPool), 1000);
        blendedPool.adminDeposit(1000);
        blendedPool.concludePendingReward(OWNER_ADDRESS);

        uint user1BalanceAfter = liquidityAsset.balanceOf(OWNER_ADDRESS);

        //checking if the user got his money now
        assertEq(
            user1BalanceAfter,
            user1BalanceBefore + 1000,
            "invalid user1 LA balance after concluding"
        );
    }

    function test_subsidingRegPoolWithBlendedPool() external {
        vm.prank(OWNER_ADDRESS);
        address poolAddress = mockPoolFactory.createPool(
            "1",
            address(liquidityAsset),
            address(liquidityLockerFactory),
            2000,
            10,
            1000,
            1000,
            100,
            500
        );

        Pool pool = Pool(poolAddress);
        vm.startPrank(pool.owner());
        pool.setBlendedPool(address(blendedPool));
        vm.stopPrank();

        //a user deposits some LA to the RegPool
        vm.startPrank(OWNER_ADDRESS);
        liquidityAsset.increaseAllowance(poolAddress, 1000);
        pool.deposit(500);
        vm.stopPrank();

        //the admin distributes rewards and takes all the LA, emptying the pool
        vm.startPrank(pool.owner());
        address[] memory holders = new address[](1);
        holders[0] = OWNER_ADDRESS;
        pool.distributeRewards(100, holders);
        pool.adminWithdraw(pool.owner(), 100);
        vm.stopPrank();

        //now let's deposit LA to the blended pool
        vm.startPrank(blendedPool.owner());
        liquidityAssetElevated.mint(blendedPool.owner(), 1000);
        liquidityAsset.increaseAllowance(address(blendedPool), 1000);
        blendedPool.adminDeposit(200);
        vm.stopPrank();

        //now let's claim reward. The blended pool will help
        vm.startPrank(OWNER_ADDRESS);
        pool.claimReward();
        vm.stopPrank();
    }

    function test_withdrawOverThreshold() external {
        address poolAddress = mockPoolFactory.createPool(
            "1",
            address(liquidityAssetElevated),
            address(liquidityLockerFactory),
            2000,
            10,
            1000,
            1000,
            100,
            500
        );

        Pool pool = Pool(poolAddress);
        liquidityAsset.increaseAllowance(poolAddress, 1000);

        uint depositAmount = 600;
        vm.startPrank(OWNER_ADDRESS);
        liquidityAssetElevated.mint(OWNER_ADDRESS, 1000);
        liquidityAssetElevated.increaseAllowance(poolAddress, 1000);
        pool.deposit(depositAmount);

        assertEq(pool.balanceOf(OWNER_ADDRESS), depositAmount);

        uint currentTime = block.timestamp;
        vm.warp(currentTime + 2000);
        vm.expectEmit(true, true, false, false);
        // The expected event signature
        emit WithdrawalOverThreshold(OWNER_ADDRESS, depositAmount);
        pool.withdraw(depositAmount);
        vm.stopPrank();
    }
}
