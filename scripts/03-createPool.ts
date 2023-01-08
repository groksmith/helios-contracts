import {ethers} from "hardhat";

const POOL_FACTORY_ADDRESS = "0xEb7ef892c8724e9691742957af1892fA957154A0";
const LIQUIDITY_LOCKER_FACTORY_ADDRESS = "0x51447bD6E1948ebfe3481B35EC9Bd141A55434EC";
const USDC_ADDRESS = "0xde637d4c445ca2aae8f782ffac8d2971b93a4998";

async function main() {
    // Get Signers
    let [owner, admin] = await ethers.getSigners();

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", owner);
    const poolFactoryContract = await poolFactoryFactory.attach(POOL_FACTORY_ADDRESS);

    const poolId = "7ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";

    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", owner);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.attach(LIQUIDITY_LOCKER_FACTORY_ADDRESS);

    console.log("Pool Id:", poolId);
    // Create Pool Contract
    await poolFactoryContract.connect(admin).createPool(
        poolId,
        USDC_ADDRESS,
        liquidityLockerFactory.address,
        10,
        12,
        100000,
        10,
        10);

    // Retrieve Pool Contract
    const pool = await poolFactoryContract.pools(poolId);
    const poolFactory = await ethers.getContractFactory("Pool", admin);
    const poolContract = poolFactory.attach(pool);
    await poolContract.finalize();
    await poolContract.setOpenToPublic(true);
}

main().catch((error) => {
    console.error(error.error.reason);
    process.exitCode = 1;
});

