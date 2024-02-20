pragma solidity 0.8.20;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";

contract BlendedPoolTestHandler is CommonBase, StdCheats, StdUtils {
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;

    BlendedPool public blendedPool;
    MockTokenERC20 public assetElevated;
    ERC20 public asset;

    uint256 public netInflows;
    uint256 public netYieldAccrued;
    uint256 public netBorrowed;
    uint256 public netDeposits;

    address[] public USER_ADDRESSES = [
    address(uint160(uint256(keccak256("user1")))),
    address(uint160(uint256(keccak256("user2")))),
    address(uint160(uint256(keccak256("user3")))),
    address(uint160(uint256(keccak256("user4")))),
    address(uint160(uint256(keccak256("user5"))))
    ];

    constructor(BlendedPool _blendedPool, MockTokenERC20 _assetElevated){
        blendedPool = _blendedPool;
        assetElevated = _assetElevated;
        asset = ERC20(assetElevated);
    }

    /// Make a deposit for a user
    function userDeposit(uint256 amount, uint256 user_idx) public virtual {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        amount = amount % type(uint80).max;

        if (asset.balanceOf(user) < amount) {
            assetElevated.mint(user, amount);
        }

        vm.prank(user);
        asset.approve(address(blendedPool), amount);

        vm.prank(user);
        blendedPool.deposit(amount);

        netInflows += amount;
        netDeposits += amount;
    }

    /// Withdraw the first deposit for a user
    function userWithdrawFirst(uint256 amount, uint256 user_idx) external {
        uint256 holderCount = blendedPool.getHoldersCount();
        if (holderCount == 0) return;

        user_idx = user_idx % holderCount;
        address user = blendedPool.getHolderByIndex(user_idx);

        vm.prank(user);
        blendedPool.withdraw(amount);
        netInflows -= amount;
        netDeposits -= amount;
    }

    function withdrawYield(uint256 user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        if (netYieldAccrued == 0) return;
        uint256 user_current_yield = blendedPool.yields(user);
        vm.prank(user);
        if (blendedPool.withdrawYield()) {
            // withdrawn
            netYieldAccrued -= user_current_yield;
        } else {
            // added to pending yields
        }
    }

    /// Withdraw the first N deposits for a user
//    function userWithdrawFirstNumFull(uint256 num_deposits, uint256 user_idx) external {
//        user_idx = user_idx % USER_ADDRESSES.length;
//        address user = USER_ADDRESSES[user_idx];
//        DepositsHolder deposits_holder = blendedPool.depositsHolder();
//        PoolLibrary.DepositInstance[] memory user_deposits = deposits_holder.getDepositsByHolder(user);
//        num_deposits = num_deposits % user_deposits.length;
//
//        uint256 shares = blendedPool.balanceOf(user);
//        if (shares == 0) return;
//
//        uint[] memory amounts = new uint[](num_deposits);
//        uint16[] memory indices = new uint16[](num_deposits);
//        for (uint16 i = 0; i < num_deposits; i++) {
//            indices[i] = i;
//            amounts[i] = user_deposits[i].amount;
//        }
//        uint256 total_amount = 0;
//        for (uint256 i = 0; i < amounts.length; i++) {
//            total_amount += amounts[i];
//        }
//        vm.prank(user);
//        blendedPool.withdraw(amounts, indices);
//        netInflows -= total_amount;
//        netDeposits -= total_amount;
//    }

    /*
    HANDLERS - Admin Workflow
    */

    uint256 public yieldPrecisionLoss;
    uint256 public timesDistributeYieldCalled;
    uint256 public maxPrecisionLossForYields;

    /// Distribute yields
//    function distributeYield() external {
//        if (netInflows == 0) return;
//        timesDistributeYieldCalled++;
//        uint256 startingSumYields = sumUserYields();
//        uint256 newYieldToDistribute = 0.1e18;
//        assetElevated.mint(address(blendedPool), newYieldToDistribute);
//
//        vm.prank(OWNER_ADDRESS);
//        blendedPool.distributeYields(newYieldToDistribute);
//        netYieldAccrued += newYieldToDistribute;
//        uint256 actualChangeInUserYields = sumUserYields() - startingSumYields;
//        yieldPrecisionLoss += newYieldToDistribute - actualChangeInUserYields;
//
//        // The maximum precision loss for this distribution is the total number of depositors minus 1
//        // example: if there are 50 depositors and the distribution is 100049, there is a precision loss of 49
//        maxPrecisionLossForYields += blendedPool.getHoldersCount() - 1;
//    }

    /// Finish pending withdrawal for a user
    function concludePendingWithdrawal(uint256 user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        uint256 pendingWithdrawalAmount = blendedPool.pendingWithdrawals(user);
        vm.prank(OWNER_ADDRESS);
        blendedPool.concludePendingWithdrawal(user);
        netInflows -= pendingWithdrawalAmount;
        netDeposits -= pendingWithdrawalAmount;
    }

    /// Finish pending yield withdrawal for a user
    function concludePendingYield(uint256 user_idx) external {
        user_idx = user_idx % USER_ADDRESSES.length;
        address user = USER_ADDRESSES[user_idx];
        uint256 pendingYieldAmount = blendedPool.pendingYields(user);
        vm.prank(OWNER_ADDRESS);
        blendedPool.concludePendingYield(user);
        netYieldAccrued -= pendingYieldAmount;
    }

    /// Borrow money from the deposits
    function borrow(uint256 amount) external {
        amount = amount % blendedPool.totalBalance();
        vm.prank(OWNER_ADDRESS);
        blendedPool.borrow(OWNER_ADDRESS, amount);
        netInflows -= amount;
        netBorrowed += amount;
    }

    /// Repay netBorrowed money to the pool
    function repay(uint256 amount) external {
        if (netInflows == 0) {
            return;
        }
        amount = amount % asset.balanceOf(OWNER_ADDRESS);
        vm.prank(OWNER_ADDRESS);
        blendedPool.repay(amount);
        netInflows += amount;
        if (amount > netBorrowed) {
            netBorrowed = 0;
        } else {
            netBorrowed -= amount;
        }
    }

    function users() public view returns (address[] memory) {
        return USER_ADDRESSES;
    }
}