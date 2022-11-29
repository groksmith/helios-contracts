import {ethers} from "hardhat";

async function main() {
    let [owner, admin] = await ethers.getSigners();
    console.log("Owner:", owner.address);
    console.log("Admin:", admin.address);

    const globalsFactory = await ethers.getContractFactory("HeliosGlobals");

    const globals = await globalsFactory.deploy(owner.address, admin.address);
    await globals.deployed();
    console.log("HeliosGlobals deployed to:", globals.address);

    await globals.setPoolDelegateAllowList(admin.address, true);
    console.log("setPoolDelegateAllowList to: ", admin.address);

    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactory = await poolFactoryFactory.deploy(globals.address);
    await poolFactory.deployed();
    console.log("Pool Factory deployed to:", poolFactory.address);

    await poolFactory.setPoolFactoryAdmin(admin.address, true);
    console.log("setPoolFactoryAdmin to: ", admin.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
