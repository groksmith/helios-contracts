import hre from "hardhat";

let ACCOUNT_OWNER = process.env.ACCOUNT_OWNER!
let ACCOUNT_ADMIN = process.env.ACCOUNT_ADMIN!
let CONTRACT_HELIOS_GLOBALS = process.env.CONTRACT_HELIOS_GLOBALS!;

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
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});