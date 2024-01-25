pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {MockTokenERC20} from "./MockTokenERC20.sol";
import "../contracts/pool/AbstractPool.sol";
import {Pool} from "../contracts/pool/Pool.sol";

import {FixtureContract} from "./FixtureContract.sol";

contract RegPoolTest is FixtureContract {
    event PendingReward(address indexed recipient, uint256 indexed amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 indexed amount);

    function setUp() public {
        fixture();
    }

    /// @notice Test attempt to deposit; checking if variables are updated correctly
    function test_depositSuccess(address user1, address user2) external {
        user1 = createInvestorAndMintLiquidityAsset(user1, 1000);
        user2 = createInvestorAndMintLiquidityAsset(user2, 1000);
        vm.assume(user1 != user2);

        vm.startPrank(user1);

        //testing initial condition i.e. zeroes
        assertEq(regPool1.balanceOf(user1), 0);
        assertEq(regPool1.totalDeposited(), 0);

        uint256 user1Deposit = 100;
        liquidityAsset.increaseAllowance(address(regPool1), user1Deposit);
        regPool1.deposit(user1Deposit);

        //user's LP balance should be 100 now
        assertEq(regPool1.balanceOf(user1), user1Deposit, "wrong LP balance for user1");

        //pool's total minted should also be user1Deposit
        assertEq(regPool1.totalDeposited(), user1Deposit, "wrong totalDeposit after user1 deposit");
        vm.stopPrank();

        //now let's test for user2
        vm.startPrank(user2);
        assertEq(regPool1.balanceOf(user2), 0, "user2 shouldn't have >0 atm");
        uint256 user2Deposit = 101;

        liquidityAsset.increaseAllowance(address(regPool1), user2Deposit);
        regPool1.deposit(user2Deposit);

        assertEq(regPool1.balanceOf(user2), user2Deposit, "wrong user2 LP balance");

        //pool's total minted should also be user1Deposit
        assertEq(regPool1.totalDeposited(), user1Deposit + user2Deposit, "wrong totalDeposited after user2");
        vm.stopPrank();
    }

    /// @notice Test attempt to deposit below minimum
    function test_depositFailure(address user) external {
        vm.startPrank(user);
        uint256 depositAmountBelowMin = 1;
        vm.expectRevert("P:DEP_AMT_BELOW_MIN");
        regPool1.deposit(depositAmountBelowMin);
    }

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function test_withdraw(address user) external {
        user = createInvestorAndMintLiquidityAsset(user, 1000);

        vm.startPrank(user);
        uint256 depositAmount = 150;
        uint256 currentTime = block.timestamp;

        liquidityAsset.increaseAllowance(address(regPool1), depositAmount);
        //the user can withdraw the sum he has deposited earlier
        regPool1.deposit(depositAmount);

        //attempt to withdraw too early fails
        uint16[] memory indices = new uint16[](1);
        indices[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount - 1;

        vm.expectRevert("P:TOKENS_LOCKED");
        regPool1.withdraw(amounts, indices);

        vm.warp(currentTime + 1000);
        regPool1.withdraw(amounts, indices);

        // but he cannot withdraw more
        vm.expectRevert("P:INSUFFICIENT_FUNDS");
        regPool1.withdraw(amounts, indices);

        vm.stopPrank();
    }

    /// @notice Test complete scenario of depositing, distribution of rewards and claim
    function test_distributeRewardsAndClaim(address user1, address user2) external {
        user1 = createInvestorAndMintLiquidityAsset(user1, 1000);
        user2 = createInvestorAndMintLiquidityAsset(user2, 1000);
        vm.assume(user1 != user2);

        //firstly the users need to deposit before withdrawing
        uint256 user1Deposit = 100;
        vm.startPrank(user1);
        liquidityAsset.increaseAllowance(address(regPool1), user1Deposit);
        regPool1.deposit(user1Deposit);
        vm.stopPrank();

        uint256 user2Deposit = 1000;
        vm.startPrank(user2);
        liquidityAsset.increaseAllowance(address(regPool1), user2Deposit);
        regPool1.deposit(user2Deposit);
        vm.stopPrank();
        address[] memory holders = new address[](2);
        holders[0] = user1;
        holders[1] = user2;

        uint256 rewardGenerated = 10000;

        //a non-pool-admin address shouldn't be able to call distributeRewards()
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        regPool1.distributeRewards(rewardGenerated, holders);

        //only the pool admin can call distributeRewards()
        address poolAdmin = regPool1.owner();
        vm.startPrank(poolAdmin);
        mintLiquidityAsset(poolAdmin, rewardGenerated);
        liquidityAsset.increaseAllowance(address(regPool1), rewardGenerated);
        regPool1.adminDeposit(rewardGenerated);
        regPool1.distributeRewards(rewardGenerated, holders);
        vm.stopPrank();

        //now we need to test if the users got assigned the correct rewards
        uint256 user1Rewards = regPool1.rewards(user1);
        uint256 user2Rewards = regPool1.rewards(user2);

        assertEq(user1Rewards, 10, "wrong reward user1");
        assertEq(user2Rewards, 100, "wrong reward user2"); //NOTE: 1 is lost as a dust value :(

        uint256 user1BalanceBefore = liquidityAsset.balanceOf(user1);
        vm.prank(user1);
        regPool1.claimReward();
        assertEq(
            liquidityAsset.balanceOf(user1) - user1BalanceBefore,
            10,
            "user1 balance not upd after claimReward()"
        );

        uint256 user2BalanceBefore = liquidityAsset.balanceOf(user2);
        vm.prank(user2);
        regPool1.claimReward();
        assertEq(
            liquidityAsset.balanceOf(user2) - user2BalanceBefore,
            100,
            "user2 balance not upd after claimReward()"
        );
    }

    function test_maxPoolSize(uint256 _maxPoolSize) external {
        _maxPoolSize = bound(_maxPoolSize, 1, 1e36);
        address poolAddress = mockPoolFactory.createPool(
            "1",
            address(liquidityAsset),
            address(liquidityLockerFactory),
            2000,
            10,
            1000,
            _maxPoolSize,
            0,
            500,
            1000
        );

        Pool pool = Pool(poolAddress);

        vm.startPrank(OWNER_ADDRESS);
        liquidityAsset.increaseAllowance(poolAddress, 1000);
        vm.expectRevert("P:MAX_POOL_SIZE_REACHED");
        pool.deposit(_maxPoolSize + 1);
        vm.stopPrank();
    }

    function test_reinvest(address user) external {
        user = createInvestorAndMintLiquidityAsset(user, 1000);
        vm.startPrank(user);

        //firstly the user needs to deposit
        uint256 user1Deposit = 1000;
        liquidityAsset.increaseAllowance(address(regPool1), user1Deposit);
        regPool1.deposit(user1Deposit);
        vm.stopPrank();

        address[] memory holders = new address[](1);
        holders[0] = user;

        //only the pool admin can call distributeRewards()
        address poolAdmin = regPool1.owner();
        vm.startPrank(poolAdmin);
        mintLiquidityAsset(poolAdmin, 1000);
        liquidityAsset.increaseAllowance(address(regPool1), 1000);
        regPool1.adminDeposit(1000);
        regPool1.distributeRewards(1000, holders);
        vm.stopPrank();

        //now the user wishes to reinvest
        vm.startPrank(user);
        uint256 userRewards = regPool1.rewards(user);
        assertEq(userRewards, 10);

        liquidityAsset.increaseAllowance(address(regPool1), userRewards);
        regPool1.reinvest(userRewards);

        uint256 userBalanceNow = regPool1.balanceOf(user);
        uint256 expected = user1Deposit + userRewards;
        assertEq(userBalanceNow, expected);

        userRewards = regPool1.rewards(user);
        assertEq(userRewards, 0);

        vm.stopPrank();
    }
}
