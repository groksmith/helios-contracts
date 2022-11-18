import {ethers} from "hardhat";

async function main() {
    let [owner, admin] = await ethers.getSigners();
    const globalsFactory = await ethers.getContractFactory("HeliosGlobals");

    const globals = await globalsFactory.deploy(owner.address, admin.address);
    await globals.deployed();
    console.log("HeliosGlobals deployed to:", globals.address);

    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactory = await poolFactoryFactory.deploy(globals.address);
    await poolFactory.deployed();

    console.log("Pool Factory deployed to:", poolFactory.address);
    console.log("Owner:", owner.address);
    console.log("Admin:", admin.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
