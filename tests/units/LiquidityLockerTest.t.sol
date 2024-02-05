pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {FixtureContract} from "../fixtures/FixtureContract.t.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";
import {LiquidityLocker} from "../../contracts/pool/LiquidityLocker.sol";

contract LiquidityLockerTest is Test, FixtureContract {

    function setUp() public {
        fixture();
    }

    function testFuzz_totalBalance(address user, uint256 amount) public {
        vm.startPrank(address(regPool1), address(regPool1));
        address liquidityLockerAddress = liquidityLockerFactory.CreateLiquidityLocker(address(liquidityAsset));
        vm.stopPrank();

        vm.startPrank(user, user);
        createInvestorAndMintLiquidityAsset(user, amount);
        liquidityAsset.approve(liquidityLockerAddress, amount);
        liquidityAsset.transfer(liquidityLockerAddress, amount);

        LiquidityLocker liquidityLocker = LiquidityLocker(liquidityLockerAddress);
        assertEq(liquidityLocker.totalBalance(), amount);
    }
}
