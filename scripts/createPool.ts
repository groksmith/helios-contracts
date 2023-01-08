import {ethers} from "hardhat";
import {UuidTool} from "uuid-tool";

async function main() {
    // Get Signers
    let [admin] = await ethers.getSigners();
    console.log("Admin:", admin.address);

    // Get PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactoryContract = await poolFactoryFactory.attach("0xD327A5E662C20766073E833102945c3C7df39f63");
    // console.log("Pool Factory address:", poolFactoryContract.address);

    const poolId = "6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b";

    console.log("Pool Id:", poolId);
    // Create Pool Contract
    // await poolFactoryContract.createPool(poolId,10, 12, 100000, 1);

    // Retrieve Pool Contract
    const pool = await poolFactoryContract.pools(poolId);
    const poolFactory = await ethers.getContractFactory("Pool");
    const poolContract = poolFactory.attach(pool);

    await console.log(await poolContract.name())
}

main().catch((error) => {
    console.error(error.error.reason);
    process.exitCode = 1;
});

