import {ethers} from "hardhat";
import {mine} from "@nomicfoundation/hardhat-network-helpers";

let CONTRACT_POOL_FACTORY = process.env.CONTRACT_POOL_FACTORY!;
let CONTRACT_LIQUIDITY_LOCKER_FACTORY = process.env.CONTRACT_LIQUIDITY_LOCKER_FACTORY!;
let CONTRACT_USDC = process.env.CONTRACT_USDC!;
let POOL_ID = process.env.POOL_ID!;

async function main() {
    const [, admin] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(CONTRACT_POOL_FACTORY);

    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", admin);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.attach(CONTRACT_LIQUIDITY_LOCKER_FACTORY);

    // Create Pool Contract
    const tx = await poolFactoryContract.createPool(
        POOL_ID,
        CONTRACT_USDC,
        liquidityLockerFactory.address,
        10,
        12,
        10000,
        10,
        1);

    await tx.wait(1);

    // Retrieve Pool Contract
    const pool = await poolFactoryContract.pools(POOL_ID);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool);
    await poolContract.finalize();
}

main().catch((error) => {
    console.error(error.error);
    process.exitCode = 1;
});

