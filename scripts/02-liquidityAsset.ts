import {ethers} from "hardhat";

const USDC_ADDRESS = "0xde637d4c445ca2aae8f782ffac8d2971b93a4998";

const global = "0xd58490F3Bc01C98C18026a1f3E31F90c0e953E44";

async function main() {
    let [owner, admin] = await ethers.getSigners();
    console.log("Owner:", owner.address);
    console.log("Admin:", admin.address);

    // Get HeliosGlobals Contract
    const heliosGlobalsFactory = await ethers.getContractFactory("HeliosGlobals");
    const heliosGlobals = await heliosGlobalsFactory.attach(global);

    // Set LiquidityAsset(s)
    await heliosGlobals.setLiquidityAsset(USDC_ADDRESS, true);
    console.log("setLiquidityAsset to: ", USDC_ADDRESS);
}

main().catch((error) => {
    console.error(error.error.reason);
    process.exitCode = 1;
});

