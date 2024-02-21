pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";
import {Pool} from "../../contracts/pool/Pool.sol";
import {PoolLibrary} from "../../contracts/library/PoolLibrary.sol";
import {PoolFactory} from "../../contracts/pool/PoolFactory.sol";

import {BlendedPoolTestHandler} from "./BlendedPoolTestHandler.t.sol";
import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BlendedPoolInvariantTest is Test {
    BlendedPoolTestHandler private handler;
    BlendedPool private blendedPool;

    ERC20 public asset;
    MockTokenERC20 private assetElevated;
    HeliosGlobals public heliosGlobals;
    PoolFactory public poolFactory;

    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;

    function setUp() external {
        vm.startPrank(OWNER_ADDRESS);

        // Setup contracts
        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS);
        poolFactory = new PoolFactory(address(heliosGlobals));
        assetElevated = new MockTokenERC20("USDT", "USDT");
        asset = ERC20(assetElevated);

        // Setup variables
        heliosGlobals.setAsset(address(asset), true);
        heliosGlobals.setPoolFactory(address(poolFactory));

        address blendedPoolAddress = poolFactory.createBlendedPool(
            address(asset),
            300,
            0 // Setting minInvestmentAmount to 0 for testing if this can create larger issues
        );

        blendedPool = BlendedPool(blendedPoolAddress);
        vm.stopPrank();

        handler = new BlendedPoolTestHandler(blendedPool, assetElevated);
        targetContract(address(handler));
    }

//    // INVARIANT #1
//    // Test that the pool's token balance is equal to:
//    //  + total deposits (net of withdrawals)
//    //  - the sum of withdrawals
//    //  + total of all yield transferred in to the locker
//    //  + total borrowed (net of repayments)
//    function invariant_pool_balance_equals_tracked_deposits() external {
//        uint256 totalNet = handler.netInflows() + handler.netYieldAccrued() + handler.netBorrowed();
//        uint256 blendedPoolTotal = asset.balanceOf(address(blendedPool)) + blendedPool.principalOut();
//
//        emit LogUint("totalNet", totalNet);
//        emit LogUint("blendedPoolTotal", blendedPoolTotal);
//
//        assertEq(totalNet, blendedPoolTotal);
//    }

//    // INVARIANT #2
//    // Test that the total deposits (net of withdrawals) is equal to the sum of all user deposit instances
//    function invariant_deposit_instances_equal_tracked_deposits() public {
//        emit LogUint("netDeposits", handler.netDeposits());
//        emit LogUint("sumUserDeposits", sumUserDeposits());
//        assertEq(sumUserDeposits(), handler.netDeposits());
//    }
//
//    // INVARIANT #3
//    // Test that the total of all deposit instances is equal to the sum of the pool's ERC20 token balances
//    function invariant_pool_erc20_equals_tracked_deposits() public {
//        emit LogUint("sumPoolTokenBalances()", sumPoolTokenBalances());
//        emit LogUint("netDeposits", handler.netDeposits());
//        assertEq(handler.netDeposits(), sumPoolTokenBalances());
//    }

    // INVARIANT #5
    // Test that the total of all deposit instances is equal to the pool's totalSupply
    function invariant_totalSupply_equals_tracked_deposits() public {
        emit LogUint("blendedPool.totalSupply()", blendedPool.totalSupply());
        emit LogUint("netDeposits", handler.netDeposits());
        assertEq(blendedPool.totalSupply(), handler.netDeposits());
    }

    // INVARIANT #6
    // Test that the sum of all user yields is equal to the the sum of all
    // amounts of yield distributed minus the total precision loss
    function invariant_total_yield() external {
        assertEq(handler.netYieldAccrued(), handler.sumUserYields());
    }

    // INVARIANT #7
    // Test that the sum of all user yields is equal to the the sum of all
    // amounts of yield distributed minus the total precision loss
    function invariant_total_yield_with_precision_loss() external {
        assertEq(handler.netYieldAccrued() - handler.yieldPrecisionLoss(), handler.sumUserYields());
    }

    // INVARIANT #8
    // Test that the precision loss for yields is less than the sum of total user count minus 1
    // for each time distributeYield is called
    function invariant_yield_precision_loss() external {
        assertLe(handler.yieldPrecisionLoss(), handler.maxPrecisionLossForYields());
    }

    // INVARIANT #9
    // Test that the total of all deposit instances is equal to the pool's totalDeposited storage variable
    function invariant_totalDeposited_greater_or_equals_tracked_deposits() public {
        emit LogUint("blendedPool.totalDeposited()", blendedPool.totalDeposited());
        emit LogUint("netDeposits", handler.netDeposits());
        assertGe(blendedPool.totalDeposited(), handler.netDeposits());
    }

    // INVARIANT #10
    // Test that the holders count equal depositors count
    function invariant_users_count_greater_or_equal_deposits_count() public {
        emit LogUint("Test users count", handler.users().length);
        emit LogUint("Holders count ", blendedPool.getHoldersCount());
        assertGe(handler.users().length, blendedPool.getHoldersCount());
    }

    event LogUint(string, uint);

    function sumUserDeposits() public view returns (uint sum){
        sum = 0;
        uint holders_count = blendedPool.getHoldersCount();
        for (uint i = 0; i < holders_count; i++) {
            address holder = blendedPool.getHolderByIndex(i);
            sum += blendedPool.totalDepositsAmount(holder);
        }
    }

    function assertEqualWithinPrecision(uint x, uint y, uint precision) internal pure returns (bool){
        return absDiff(x, y) <= precision;
    }

    function absDiff(uint x, uint y) internal pure returns (uint){
        if (x > y) {
            return x - y;
        } else {
            return y - x;
        }
    }
}
