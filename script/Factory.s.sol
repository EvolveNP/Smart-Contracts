// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract FactoryScript is Script {
    function setUp() public {}

    function run() public {
        uint256 chainId = block.chainid;
        console.log("Deploying to chain:", chainId);
        vm.startBroadcast();

        address factoryImplementation = address(new Factory());
        Factory factory =
            Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        console.log("Factory deployed at:", address(factory));
        vm.stopBroadcast();
    }
}
