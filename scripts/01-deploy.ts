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
DEPLOY::HeliosGlobals deployed to: 0xd47eE5c092786985A582c6c2f951989634213740
DEPLOY::Pool Factory deployed to: 0x00900af6eaeE07F8F2ce6B97411542f8d5F568f1
DEPLOY::Liquidity Factory deployed to: 0x905dEd625e1de5782647b8dAF2A16652062dee08

LL::0x905dEd625e1de5782647b8dAF2A16652062dee08
*/