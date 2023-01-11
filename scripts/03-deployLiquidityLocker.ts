import {ethers} from "hardhat";

let CONTRACT_HELIOS_GLOBALS = process.env.CONTRACT_HELIOS_GLOBALS!;
let CONTRACT_POOL_FACTORY = process.env.CONTRACT_POOL_FACTORY!;

async function main() {
    let [owner] = await ethers.getSigners();

    const heliosGlobalsFactory = await ethers.getContractFactory("HeliosGlobals", owner);
    const heliosGlobals = await heliosGlobalsFactory.attach(CONTRACT_HELIOS_GLOBALS);

    // Deploy Liquidity Locker Factory
    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", owner);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.deploy();
    await liquidityLockerFactory.deployed();
    console.log("CONTRACT::Liquidity Factory deployed to:", liquidityLockerFactory.address);

    await heliosGlobals.setValidPoolFactory(CONTRACT_POOL_FACTORY, true);
    await heliosGlobals.setValidSubFactory(CONTRACT_POOL_FACTORY, liquidityLockerFactory.address, true);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
