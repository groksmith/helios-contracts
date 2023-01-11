import {ethers} from "hardhat";

let CONTRACT_HELIOS_GLOBALS = process.env.CONTRACT_HELIOS_GLOBALS!;

async function main() {
    const [owner, admin] = await ethers.getSigners();

    // Deploy Pool Factory
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory", owner);
    const poolFactory = await poolFactoryFactory.deploy(CONTRACT_HELIOS_GLOBALS);
    await poolFactory.deployed();
    console.log("CONTRACT::Pool Factory deployed to:", poolFactory.address);

    // Set Pool Factory Admin
    await poolFactory.setPoolFactoryAdmin(admin.address, true);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
