// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";

contract FactoryScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        Factory factory = new Factory();

        console.log("Factory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
