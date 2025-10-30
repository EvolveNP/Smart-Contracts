// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {USDC} from "../src/mock/USDC.sol";
import {Config} from "forge-std/Config.sol";

contract USDCScript is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", true);
       
        uint256 chainId = block.chainid;
        console.log("Deploying to chain:", chainId);

        vm.startBroadcast();
        address usdc = address(new USDC());
        console.log("USDC deployed at:", usdc);
        config.set("usdc", usdc);
        vm.stopBroadcast();
    }
}
