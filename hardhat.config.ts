// noinspection JSUnusedGlobalSymbols

import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.8",
        settings: {
            optimizer: {
                enabled: false,
                runs: 300,
            }
        },
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        url: "http://localhost:8545",
        coinmarketcap: "5b857a1c-6633-4d01-b5da-279d35141c79"
    },
};

export default config;
