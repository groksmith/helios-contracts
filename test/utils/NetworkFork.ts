import {network} from "hardhat";

const forkApi = process.env.MAIN_NET_FORK_API_KEY!;
async function fork_network() {
    console.log('fork_network');

    return await network.provider.request({
        method: "hardhat_reset",
        params: [
            {
                forking: {
                    jsonRpcUrl: forkApi,
                }
            }
        ]
    });
}

async function fork_reset() {
    return network.provider.request({
        method: "hardhat_reset",
        params: [],
    });
}

async function mine_blocks(numberOfBlocks: number) {
    for (let i = 0; i < numberOfBlocks; i++) {
        await network.provider.send("evm_mine");
    }
}

async function increase_block_timestamp(time: string) {
    return network.provider.send("evm_increaseTime", [time]);
}

async function time_travel(time: string) {
    await increase_block_timestamp(time);
    await mine_blocks(1);
}

export {
    fork_network,
    time_travel,
    fork_reset,
    mine_blocks,
    increase_block_timestamp
};
