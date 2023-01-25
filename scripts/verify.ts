import hre from "hardhat";

let ACCOUNT_OWNER = process.env.ACCOUNT_OWNER!
let ACCOUNT_ADMIN = process.env.ACCOUNT_ADMIN!
let CONTRACT_HELIOS_GLOBALS = process.env.CONTRACT_HELIOS_GLOBALS!;
let CONTRACT_POOL_FACTORY = process.env.CONTRACT_POOL_FACTORY!;
let CONTRACT_LIQUIDITY_LOCKER_FACTORY = process.env.CONTRACT_LIQUIDITY_LOCKER_FACTORY!;
let CONTRACT_POOL = process.env.CONTRACT_POOL!;
let CONTRACT_USDC = process.env.CONTRACT_USDC!;

async function main() {
    try {
        await hre.run("verify:verify", {
            address: CONTRACT_HELIOS_GLOBALS,
            constructorArguments: [
                ACCOUNT_OWNER,
                ACCOUNT_ADMIN
            ],
        });
    } catch (error) {
        console.log(error)
    }

    try {
        await hre.run("verify:verify", {
            address: CONTRACT_POOL_FACTORY,
            constructorArguments: [
                CONTRACT_HELIOS_GLOBALS
            ],
        });
    } catch (error) {
        console.log(error)
    }

    try {
        await hre.run("verify:verify", {
            address: CONTRACT_LIQUIDITY_LOCKER_FACTORY,
            constructorArguments: [],
        });
    } catch (error) {
        console.log(error)
    }

    try {
        await hre.run("verify:verify", {
            address: CONTRACT_LIQUIDITY_LOCKER_FACTORY,
            constructorArguments: [],
        });
    } catch (error) {
        console.log(error)
    }

    try {
        await hre.run("verify:verify", {
            address: CONTRACT_POOL,
            constructorArguments: [
                ACCOUNT_ADMIN,
                CONTRACT_USDC,
                CONTRACT_LIQUIDITY_LOCKER_FACTORY,
                10,
                12,
                10000,
                100000 * 10 ** 6,
                10 ** 6
            ],
        });
    } catch (error) {
        console.log(error)
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});