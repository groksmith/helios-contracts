import {ethers} from "hardhat";

async function main() {
    // Get Signers
    let [owner, admin] = await ethers.getSigners();
    console.log("Owner:", owner.address);
    console.log("Admin:", admin.address);

    // Create HeliosGlobals Contract
    const globalsFactory = await ethers.getContractFactory("HeliosGlobals");
    const globalsContract = await globalsFactory.deploy(owner.address, admin.address);
    await globalsContract.deployed();
    console.log("HeliosGlobals deployed to:", globalsContract.address);

    // Set Pool Delegate Allow List
    await globalsContract.setPoolDelegateAllowList(admin.address, true);

    // Create PoolFactory Contract
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactoryContract = await poolFactoryFactory.deploy(globalsContract.address);
    await poolFactoryContract.deployed();
    console.log("Pool Factory deployed to:", poolFactoryContract.address);

    // Set Pool Factory Admin
    await poolFactoryContract.setPoolFactoryAdmin(admin.address, true);

    // Create Pool Contract
    await poolFactoryContract.connect(admin).createPool(10, 12, 100000, 1);

    // Retrieve Pool Contract
    const pool = await poolFactoryContract.pools(0)
    const poolFactory = await ethers.getContractFactory("Pool");
    const poolContract = poolFactory.attach(pool);

    // TODO: next steps
    await console.log(await poolContract.apy())
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
