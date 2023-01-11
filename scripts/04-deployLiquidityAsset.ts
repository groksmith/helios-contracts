import {ethers} from "hardhat";

let HELIOS_GLOBALS = process.env.CONTRACT_HELIOS_GLOBALS!;
let CONTRACT_USDC = process.env.CONTRACT_USDC!;

async function main() {
    let [owner] = await ethers.getSigners();

    // Get HeliosGlobals Contract
    const heliosGlobalsFactory = await ethers.getContractFactory("HeliosGlobals", owner);
    const heliosGlobals = await heliosGlobalsFactory.attach(HELIOS_GLOBALS);

    // Set LiquidityAsset(s)
    await heliosGlobals.setLiquidityAsset(CONTRACT_USDC, true);
    console.log("setLiquidityAsset to: ", CONTRACT_USDC);
}

main().catch((error) => {
    console.error(error.error.reason);
    process.exitCode = 1;
});

