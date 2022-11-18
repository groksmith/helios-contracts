import {ethers} from "hardhat";

async function main() {
    let [owner, admin] = await ethers.getSigners();
    const poolFactoryFactory = await ethers.getContractFactory("PoolFactory");
    const poolFactoryContract = poolFactoryFactory.attach('0x1e6b007Ac14a08e141B996d0398B281B3ecacA59');
    await poolFactoryContract.setPoolFactoryAdmin(admin.address, true);
    const poolCreated = await poolFactoryContract.connect(admin).createPool(10, 12, 100000, 1);
    console.log(poolCreated);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
