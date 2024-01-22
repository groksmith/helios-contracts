pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockPoolFactory} from "./MockPoolFactory.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {LiquidityLockerFactory} from "../contracts/pool/LiquidityLockerFactory.sol";
import {LiquidityLocker} from "../contracts/pool/LiquidityLocker.sol";
import {PoolFactory} from "../contracts/pool/PoolFactory.sol";
import {BlendedPool} from "../contracts/pool/BlendedPool.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {AbstractPool} from "../contracts/pool/AbstractPool.sol";

abstract contract FixtureContract {
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;
    address public constant USER_ADDRESS = 0x4F8fF72C3A17B571D4a1671d5ddFbcf48187FBCa;

    HeliosGlobals public heliosGlobals;
    ERC20 public liquidityAsset;
    MockERC20 public liquidityAssetElevated;
    PoolFactory public poolFactory;
    MockPoolFactory public mockPoolFactory;
    BlendedPool public blendedPool;
    Pool public regPool1;
    Pool public regPool2;
    LiquidityLockerFactory public liquidityLockerFactory;
    LiquidityLockerFactory public liquidityLockerFactory2;

    function fixture() public {
        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS);
        liquidityAssetElevated = new MockERC20("USDT", "USDT");
        liquidityAsset = ERC20(liquidityAssetElevated);
        liquidityAssetElevated.mint(OWNER_ADDRESS, 1000);
        liquidityAssetElevated.mint(USER_ADDRESS, 1000);
        poolFactory = new PoolFactory(address(heliosGlobals));
        mockPoolFactory = new MockPoolFactory(address(heliosGlobals));
        liquidityLockerFactory = new LiquidityLockerFactory();
        blendedPool = new BlendedPool(
            address(liquidityAsset),
            address(liquidityLockerFactory),
            1000,
            200,
            300,
            100,
            500,
            1000
        );
    }
}
