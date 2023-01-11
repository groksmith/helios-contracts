import {ethers} from "hardhat";

async function main() {
    let [owner, admin] = await ethers.getSigners();
    console.log("ACCOUNT::Owner:", owner.address);
    console.log("ACCOUNT::Admin:", admin.address);

    // Deploy HeliosGlobals Contract
    const globalsFactory = await ethers.getContractFactory("HeliosGlobals");
    const globals = await globalsFactory.deploy(owner.address, admin.address);
    await globals.deployed();
    console.log("CONTRACT::HeliosGlobals deployed to:", globals.address);

    // Set Pool Delegate Allow List
    await globals.setPoolDelegateAllowList(admin.address, true);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
