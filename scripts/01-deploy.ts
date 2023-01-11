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

    // Deploy Pool Factory
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactory = await poolFactoryFactory.deploy(globals.address);
    await poolFactory.deployed();
    console.log("CONTRACT::Pool Factory deployed to:", poolFactory.address);

    // Set Pool Factory Admin
    await poolFactory.setPoolFactoryAdmin(admin.address, true);

    // Deploy Liquidity Locker Factory
    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", owner);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.deploy();
    await liquidityLockerFactory.deployed();
    console.log("CONTRACT::Liquidity Factory deployed to:", liquidityLockerFactory.address);

    await globals.setValidPoolFactory(poolFactory.address, true);
    await globals.setValidSubFactory(poolFactory.address, liquidityLockerFactory.address, true);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
