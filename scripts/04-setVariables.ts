import {ethers} from "hardhat";

let CONTRACT_HELIOS_GLOBALS = process.env.CONTRACT_HELIOS_GLOBALS!;
let CONTRACT_POOL_FACTORY = process.env.CONTRACT_POOL_FACTORY!;
let CONTRACT_LIQUIDITY_LOCKER_FACTORY = process.env.CONTRACT_LIQUIDITY_LOCKER_FACTORY!;
let CONTRACT_USDC = process.env.CONTRACT_USDC!;

async function main() {
    const [owner, admin] = await ethers.getSigners();

    const heliosGlobalsFactory = await ethers.getContractFactory("HeliosGlobals", owner);
    const heliosGlobals = await heliosGlobalsFactory.attach(CONTRACT_HELIOS_GLOBALS);

    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(CONTRACT_POOL_FACTORY);

    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", admin);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.attach(CONTRACT_LIQUIDITY_LOCKER_FACTORY);

    // Set Pool Delegate Allow List
    const txSetPoolDelegateAllowList = await heliosGlobals.connect(owner).setPoolDelegateAllowList(admin.address, true);
    await txSetPoolDelegateAllowList.wait(1);
    console.log("VARIABLES::SetPoolDelegateAllowList:", admin.address);

    // Set Pool Factory Admin
    const txSetPoolFactoryAdmin = await poolFactoryContract.connect(owner).setPoolFactoryAdmin(admin.address, true);
    await txSetPoolFactoryAdmin.wait(1);
    console.log("VARIABLES::SetPoolFactoryAdmin:", admin.address);

    const txSetValidPoolFactory = await heliosGlobals.connect(owner).setValidPoolFactory(CONTRACT_POOL_FACTORY, true);
    await txSetValidPoolFactory.wait(1);
    console.log("VARIABLES::SetValidPoolFactory:", CONTRACT_POOL_FACTORY);

    const txSetValidSubFactory = await heliosGlobals.connect(owner).setValidSubFactory(CONTRACT_POOL_FACTORY, liquidityLockerFactory.address, true);
    await txSetValidSubFactory.wait(1);
    console.log("VARIABLES::SetValidSubFactory:", liquidityLockerFactory.address);

    // Set LiquidityAsset(s)
    const txSetLiquidityAsset = await heliosGlobals.connect(owner).setLiquidityAsset(CONTRACT_USDC, true);
    await txSetLiquidityAsset.wait(1);
    console.log("VARIABLES::SetLiquidityAsset:", CONTRACT_USDC);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
