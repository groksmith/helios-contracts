import {ethers} from "hardhat";
import {mine} from "@nomicfoundation/hardhat-network-helpers";

async function main() {
    let POOL_FACTORY_ADDRESS = process.env.POOL_FACTORY_ADDRESS!;
    let LIQUIDITY_LOCKER_FACTORY_ADDRESS = process.env.LIQUIDITY_LOCKER_FACTORY_ADDRESS!;
    let USDC = process.env.USDC_ADDRESS!;
    let POOL_ID = process.env.CONTRACT_POOL!;

    // Get Signers
    let [, admin] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(POOL_FACTORY_ADDRESS);

    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", admin);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.attach(LIQUIDITY_LOCKER_FACTORY_ADDRESS);

    // Create Pool Contract
    await poolFactoryContract.createPool(
        POOL_ID,
        USDC,
        liquidityLockerFactory.address,
        10,
        12,
        10000,
        10,
        1);

    // Retrieve Pool Contract
    const pool = await poolFactoryContract.pools(POOL_ID);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool);
    await poolContract.finalize();
    await mine(1);
}

main().catch((error) => {
    console.error(error.error);
    process.exitCode = 1;
});

