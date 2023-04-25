import {ethers} from "hardhat";
import {expect} from "chai";
import {Contract} from "ethers";

function getSlot(userAddress: string, mappingSlot: number | undefined) {
    return ethers.utils.solidityKeccak256(
        ["uint256", "uint256"],
        [userAddress, mappingSlot]
    );
}

async function checkSlot(erc20: Contract, mappingSlot: number) {
    const contractAddress = erc20.address;
    const userAddress = ethers.constants.AddressZero;

    // the slot must be a hex string stripped of leading zeros! no padding!
    // https://ethereum.stackexchange.com/questions/129645/not-able-to-set-storage-slot-on-hardhat-network
    const balanceSlot = getSlot(userAddress, mappingSlot);

    // storage value must be 32 bytes long padded with leading zeros hex string
    const value = 0xDEADBEEF;
    // @ts-ignore
    const storageValue = ethers.utils.hexlify(ethers.utils.zeroPad(value, 32));

    await ethers.provider.send(
        "hardhat_setStorageAt",
        [
            contractAddress,
            balanceSlot,
            storageValue
        ]
    );

    return await erc20.balanceOf(userAddress) == value;
}

async function findBalanceSlot (erc20: Contract) {
    const snapshot = await ethers.provider.send("evm_snapshot", []);
    for (let slotNumber = 0; slotNumber < 100; slotNumber++) {
        try {
            if (await checkSlot(erc20, slotNumber)) {
                await ethers.provider.send("evm_revert", [snapshot]);
                return slotNumber;
            }
        } catch {
        }
        await ethers.provider.send("evm_revert", [snapshot]);
    }
}

export async function changeUSDCOwnership(signerAddress: string, usdcAddress: string) {
    const usdc = await ethers.getContractAt("IERC20Metadata", usdcAddress);
    const mappingSlot = await findBalanceSlot(usdc);

    // calculate balanceOf[signerAddress] slot
    const signerBalanceSlot = getSlot(signerAddress, mappingSlot);

    // set it to the value
    const value = ethers.utils.hexlify(123456789);
    await ethers.provider.send(
        "hardhat_setStorageAt",
        [
            usdc.address,
            signerBalanceSlot,
            ethers.utils.hexlify(ethers.utils.zeroPad(value, 32))
        ]
    )

    // check that the user balance is equal to the expected value
    expect(await usdc.balanceOf(signerAddress)).to.be.eq(value);
}