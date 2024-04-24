pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {HeliosUSD} from "../../contracts/token/HeliosUSD.sol";

contract HeliosUSDTest is Test {
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;
    HeliosUSD private heliosUsd;

    function setUp() public {
        heliosUsd = new HeliosUSD(OWNER_ADDRESS);
    }

    function test_mint_not_admin(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(user != OWNER_ADDRESS);

        vm.expectRevert();
        heliosUsd.mint(user, amount);
    }

    function test_mint_admin(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(user != OWNER_ADDRESS);

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);
        heliosUsd.mint(user, amount);

        assertEq(heliosUsd.balanceOf(user), amount);
    }

    function test_decimals() public {
        assertEq(heliosUsd.decimals(), 6);
    }
}