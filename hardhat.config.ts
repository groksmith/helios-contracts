// noinspection JSUnusedGlobalSymbols

import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";

const ALCHEMY_MAIN_NET_API_KEY = "https://eth-mainnet.g.alchemy.com/v2/IGBhQoY7nzZOHZ56Od9CuhVj3jiJ58KU";

const ALCHEMY_API_KEY = "Vh6E2PGEO2PplkuLh0z0fDhlsPN3DHlc";
const GOERLI_OWNER_PRIVATE_KEY = "a43c7fdc611841d943a3b54faacd13bc29f73e0081e9e2800fef4167ecb876af";
const GOERLI_ADMIN_PRIVATE_KEY = "6a91dbcfcac54182fad12d2049103917c3f8fc1d09cb7f01a25b6caa986a5985";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.8",
        settings: {
            optimizer: {
                enabled: true,
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
    abiExporter: {
        path: './abi',
        only: ['Pool', 'PoolFactory', 'HeliosGlobals'],
        runOnCompile: true,
        flat: true,
        spacing: 2,
        pretty: false,
    },

    networks: {
        hardhat: {
            chainId: 31337,
            forking:{
                url: ALCHEMY_MAIN_NET_API_KEY,
            }
        },
        goerli: {
            url: `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
            accounts: [GOERLI_OWNER_PRIVATE_KEY, GOERLI_ADMIN_PRIVATE_KEY]
        }
    }
};

export default config;
