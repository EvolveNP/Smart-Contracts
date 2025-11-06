// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract TreasuryWalletScript is Script, Config {
    function test() public {}

    function run() public {
        uint256 chainId = block.chainid;
        console.log("Deploying to chain:", chainId);

        _loadConfig("./deployments.toml", true);

        vm.startBroadcast();

        TreasuryWallet treasuryWalletImplementation = new TreasuryWallet();

        address treasuryWalletBeacon = address(new UpgradeableBeacon(address(treasuryWalletImplementation), msg.sender));

        console.log("Treasury wallet beacon deployed at:", treasuryWalletBeacon);

        config.set("treasuryWalletBeacon", treasuryWalletBeacon);
        config.set("treasuryWalletImplementation", address(treasuryWalletImplementation));

        vm.stopBroadcast();
    }
}
