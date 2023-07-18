import {HardhatUserConfig} from 'hardhat/types';
import "@nomiclabs/hardhat-waffle";
import '@nomiclabs/hardhat-ethers';
import 'hardhat-deploy';
import '@typechain/hardhat';
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100
                    }
                }
            },
            {
                version: "0.8.17",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100
                    }
                }
            }
        ]

    }
}
export default config;

