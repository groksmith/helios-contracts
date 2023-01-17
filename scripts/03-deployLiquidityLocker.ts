import {ethers} from "hardhat";

async function main() {
    const [owner] = await ethers.getSigners();

    // Deploy Liquidity Locker Factory
    const liquidityLockerFactoryFactory = await ethers.getContractFactory("LiquidityLockerFactory", owner);
    const liquidityLockerFactory = await liquidityLockerFactoryFactory.deploy();
    await liquidityLockerFactory.deployed();
    console.log("CONTRACT::Liquidity Locker Factory deployed to:", liquidityLockerFactory.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
