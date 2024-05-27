pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function configureMinter(address minter, uint256 minterAllowedAmount) external;
    function masterMinter() external view returns (address);
    function approve(address spender, uint256 value) external returns (bool);
}

contract TestTransferFrom is Test {
    BlendedPool internal blended_pool = BlendedPool(0xe54b0C7dad72fb102ADE2b1B9F4EEce69408Ab36);
    IUSDC internal usdc = IUSDC(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address internal constant user = 0x4F8fF72C3A17B571D4a1671d5ddFbcf48187FBCa;
    address internal constant amm = 0x1416D46ebf8Afc4efE1942d7d8E14459AaBC7891;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org", 13604940);

        vm.prank(usdc.masterMinter());
        usdc.configureMinter(address(this), type(uint256).max);
        usdc.mint(user, 1000e6);
    }

    function test_check_amm() public {
        // amm is not a holder
        vm.assertEq(blended_pool.holderExists(amm), false);

        vm.startPrank(user);
        // Get HLSp tokens
        usdc.approve(address(blended_pool), 100e6);
        blended_pool.deposit(100e6);

        // Send HLSp tokens to amm
        blended_pool.transfer(amm, 1);
        vm.stopPrank();

        // amm is a holder
        vm.assertEq(blended_pool.holderExists(amm), true);
    }
}