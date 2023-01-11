import {ethers} from "hardhat";

async function main() {
    let global = process.env.CONTRACT_HELIOS_GLOBALS!;
    let USDC = process.env.USDC_ADDRESS!;

    let [owner, admin] = await ethers.getSigners();
    console.log("Owner:", owner.address);
    console.log("Admin:", admin.address);

    // Get HeliosGlobals Contract
    const heliosGlobalsFactory = await ethers.getContractFactory("HeliosGlobals");
    const heliosGlobals = await heliosGlobalsFactory.attach(global);

    // Set LiquidityAsset(s)
    await heliosGlobals.setLiquidityAsset(USDC, true);
    console.log("setLiquidityAsset to: ", USDC);
}

main().catch((error) => {
    console.error(error.error.reason);
    process.exitCode = 1;
});

