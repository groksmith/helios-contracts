import {ethers} from "hardhat";
import {mine} from "@nomicfoundation/hardhat-network-helpers";

const POOL_FACTORY_ADDRESS = "0x00900af6eaeE07F8F2ce6B97411542f8d5F568f1";
const LIQUIDITY_LOCKER_FACTORY_ADDRESS = "0x905dEd625e1de5782647b8dAF2A16652062dee08";
const USDC_ADDRESS = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";

async function main() {
    // Get Signers
    let [owner, admin] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", admin);
    const poolFactoryContract = await poolFactoryFactory.attach(POOL_FACTORY_ADDRESS);

    const poolId = "1110bd7f-11c0-43da-975e-2a8ad9ebae0b";

    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", admin);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.attach(LIQUIDITY_LOCKER_FACTORY_ADDRESS);

    // Create Pool Contract
    await poolFactoryContract.createPool(
        poolId,
        USDC_ADDRESS,
        liquidityLockerFactory.address,
        10,
        12,
        10000,
        10,
        1);

    // Retrieve Pool Contract
    const pool = await poolFactoryContract.pools(poolId);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool);
    await poolContract.finalize();
    await mine(1);
}

main().catch((error) => {
    console.error(error.error.reason);
    process.exitCode = 1;
});

