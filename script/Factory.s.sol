// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Config} from "forge-std/Config.sol";

contract FactoryScript is Script, Config {
    function test() public {}

    function setUp() public {}

    function run() public {
        uint256 chainId = block.chainid;
        console.log("Deploying to chain:", chainId);
        _loadConfig("./deployments.toml", true);

        address poolManager = config.get("poolManager").toAddress();
        address treasuryWalletBeacon = config.get("treasuryWalletBeacon").toAddress();
        address donationWalletBeacon = config.get("donationWalletBeacon").toAddress();
        address usdc = config.get("usdc").toAddress();
        address positionManager = config.get("positionManager").toAddress();
        address router = config.get("router").toAddress();
        address quoter = config.get("quoter").toAddress();
        address stateView = config.get("stateView").toAddress();
        address admin = config.get("admin").toAddress();
        address registry = config.get("registry").toAddress();
        address permit2 = config.get("permit2").toAddress();

        vm.startBroadcast();

        address factoryImplementation = address(new Factory());
        Factory factory =
            Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        console.log("Factory deployed at:", address(factory));

        factory.initialize(
            registry,
            poolManager,
            positionManager,
            router,
            permit2,
            quoter,
            admin,
            treasuryWalletBeacon,
            donationWalletBeacon,
            stateView
        );

        config.set("factoryImplementation", factoryImplementation);
        config.set("factory", address(factory));
        vm.stopBroadcast();
    }
}
