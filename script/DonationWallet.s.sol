// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {DonationWallet} from "../src/DonationWallet.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DonationWalletScript is Script, Config {
    function test() public {}
    
    function run() public {
        uint256 chainId = block.chainid;
        console.log("Deploying to chain:", chainId);

        _loadConfig("./deployments.toml", true);

        vm.startBroadcast();

        DonationWallet donationWalletImplementation = new DonationWallet();

        address donationWalletBeacon = address(new UpgradeableBeacon(address(donationWalletImplementation), msg.sender));

        console.log("Donation deployed at:", address(donationWalletBeacon));

        config.set("donationWalletBeacon", donationWalletBeacon);
        config.set("donationWalletImplementation", address(donationWalletImplementation));
        vm.stopBroadcast();

        console.log("\nDeployment complete! Addresses saved to deployments.toml");
    }
}
