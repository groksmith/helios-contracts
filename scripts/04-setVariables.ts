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
    await heliosGlobals.setPoolDelegateAllowList(admin.address, true);

    // Set Pool Factory Admin
    await poolFactoryContract.setPoolFactoryAdmin(admin.address, true);

    await heliosGlobals.setValidPoolFactory(CONTRACT_POOL_FACTORY, true);
    await heliosGlobals.setValidSubFactory(CONTRACT_POOL_FACTORY, liquidityLockerFactory.address, true);

    // Set LiquidityAsset(s)
    await heliosGlobals.setLiquidityAsset(CONTRACT_USDC, true);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
