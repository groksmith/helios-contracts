pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {LiquidityLockerFactory} from "../contracts/pool/LiquidityLockerFactory.sol";
import {PoolFactory} from "../contracts/pool/PoolFactory.sol";

abstract contract FixtureContract {
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;
    address public constant ADMIN_ADDRESS = 0x4F8fF72C3A17B571D4a1671d5ddFbcf48187FBCa;

    HeliosGlobals public heliosGlobals;
    ERC20 public liquidityAsset;
    PoolFactory public poolFactory;
    LiquidityLockerFactory public liquidityLockerFactory;

    function fixture() public{
        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS, ADMIN_ADDRESS);
        liquidityAsset = new ERC20("USDT", "USDT");
        poolFactory = new PoolFactory(address(heliosGlobals));
        liquidityLockerFactory = new LiquidityLockerFactory();
    }
}