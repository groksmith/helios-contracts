import {ethers} from "hardhat";

async function main() {
    let [owner, admin] = await ethers.getSigners();
    const globalsFactory = await ethers.getContractFactory("HeliosGlobals");

    const globalsContract = await globalsFactory.deploy(owner.address, admin.address);
    await globalsContract.deployed();
    await globalsContract.setPoolDelegateAllowList(admin.address, true);
    console.log("HeliosGlobals deployed to:", globalsContract.address);

    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactoryContract = await poolFactoryFactory.deploy(globalsContract.address);
    await poolFactoryContract.deployed();

    await poolFactoryContract.setPoolFactoryAdmin(admin.address, true);

    console.log("Pool Factory deployed to:", poolFactoryContract.address);
    console.log("Owner:", owner.address);
    console.log("Admin:", admin.address);

    await poolFactoryContract.connect(admin).createPool(10, 12, 100000, 1);

    const pool = await poolFactoryContract.pools(0)
    await console.log(pool)

    const poolFactory = await ethers.getContractFactory("Pool");
    const poolContract = poolFactory.attach(pool);

    await console.log(await poolContract.apy())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
