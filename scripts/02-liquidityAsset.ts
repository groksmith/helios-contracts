import {ethers} from "hardhat";

const USDC_ADDRESS = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";

const global = "0xd47eE5c092786985A582c6c2f951989634213740";

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

