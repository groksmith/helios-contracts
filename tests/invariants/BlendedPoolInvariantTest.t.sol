pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

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

    // Test that the holders count equal depositors count
    function invariant_users_count_greater_or_equal_deposits_count() public {
        emit LogUint("Test users count", handler.users().length);
        emit LogUint("Holders count ", blendedPool.getHoldersCount());
        assertGe(handler.users().length, blendedPool.getHoldersCount());
    }

//    // INVARIANT #1
//    // Test that the pool's token balance is equal to:
//    //  + total deposits (net of withdrawals)
//    //  - the sum of withdrawals
//    //  + total of all yield transferred in to the locker
//    //  + total borrowed (net of repayments)
//    function invariant_pool_balance_equals_tracked_deposits() external {
//        uint256 totalNet = handler.netInflows() + handler.netYieldAccrued() - handler.netBorrowed();
//        uint256 blendedPoolTotal = asset.balanceOf(address(blendedPool)) + blendedPool.principalOut();
//
//        emit LogUint("totalNet", totalNet);
//        emit LogUint("blendedPoolTotal", blendedPoolTotal);
//
//        assertEq(totalNet, blendedPoolTotal);
//    }

    // Test that totalSupply >= locked deposits sum
    function invariant_pool_totalSupply_greater_or_equal_locked_deposits() public {
        emit LogUint("handler.sumUserLockedTokens()", handler.sumUserLockedTokens());
        emit LogUint("blendedPool.totalSupply()", blendedPool.totalSupply());
        assertGe(blendedPool.totalSupply(), handler.sumUserLockedTokens());
    }

    // Test that the total of all deposit instances is equal to the pool's totalSupply
    function invariant_totalSupply_equals_tracked_deposits() public {
        emit LogUint("blendedPool.totalSupply()", blendedPool.totalSupply());
        emit LogUint("netDeposits", handler.netDeposits());
        assertEq(blendedPool.totalSupply(), handler.netDeposits());
    }

    // Test that the total of all deposit instances is equal to the pool's totalDeposited storage variable
    function invariant_totalDeposited_greater_or_equals_tracked_deposits() public {
        emit LogUint("blendedPool.totalDeposited()", blendedPool.totalDeposited());
        emit LogUint("netDeposits", handler.netDeposits());
        assertGe(blendedPool.totalDeposited(), handler.netDeposits());
    }

//    // Test that the sum of all user yields is equal to the the sum of all
//    // amounts of yield distributed minus the total precision loss
//    function invariant_total_yield() external {
//        assertEq(handler.netYieldAccrued() - handler.yieldPrecisionLoss(), handler.sumUserYields());
//    }

    // Test that yieldPrecisionLoss <= maxPrecisionLossForYields
    function invariant_yield_precision_loss_less_or_equal_max_precision_loss() external {
        emit LogUint("handler.yieldPrecisionLoss()", handler.yieldPrecisionLoss());
        emit LogUint("handler.maxPrecisionLossForYields()", handler.maxPrecisionLossForYields());

        assertLe(handler.yieldPrecisionLoss(), handler.maxPrecisionLossForYields());
    }

    event LogUint(string, uint);

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
