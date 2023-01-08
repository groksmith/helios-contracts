import {ethers} from "hardhat";

async function main() {
    let [owner, admin] = await ethers.getSigners();
    console.log("ACCOUNT::Owner:", owner.address);
    console.log("ACCOUNT::Admin:", admin.address);

    // Deploy HeliosGlobals Contract
    const globalsFactory = await ethers.getContractFactory("HeliosGlobals");
    const globals = await globalsFactory.deploy(owner.address, admin.address);
    await globals.deployed();
    console.log("DEPLOY::HeliosGlobals deployed to:", globals.address);

    // Set Pool Delegate Allow List
    await globals.setPoolDelegateAllowList(admin.address, true);

    // Deploy Pool Factory
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactory = await poolFactoryFactory.deploy(globals.address);
    await poolFactory.deployed();
    console.log("DEPLOY::Pool Factory deployed to:", poolFactory.address);

    // Set Pool Factory Admin
    await poolFactory.setPoolFactoryAdmin(admin.address, true);

    // Deploy Liquidity Locker Factory
    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", owner);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.deploy();
    await liquidityLockerFactory.deployed();
    console.log("DEPLOY::Liquidity Factory deployed to:", liquidityLockerFactory.address);

    await globals.setValidPoolFactory(poolFactory.address, true);
    await globals.setValidSubFactory(poolFactory.address, liquidityLockerFactory.address, true);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

/*
ACCOUNT::Owner: 0xb5d048FB808ebAe19aB52c2Eae95b4cc1636Bb63
ACCOUNT::Admin: 0x2F4e1636358BF631965AAffC1BFa068c52Bb36B7
DEPLOY::HeliosGlobals deployed to: 0xd58490F3Bc01C98C18026a1f3E31F90c0e953E44
DEPLOY::Pool Factory deployed to: 0xEb7ef892c8724e9691742957af1892fA957154A0
DEPLOY::Liquidity Factory deployed to: 0x51447bD6E1948ebfe3481B35EC9Bd141A55434EC
*/