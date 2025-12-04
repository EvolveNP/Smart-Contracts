// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Config} from "forge-std/Config.sol";
import {V4Quoter} from "@uniswap/universal-router/lib/v4-periphery/src/lens/V4Quoter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

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
        address positionManager = config.get("positionManager").toAddress();
        address router = config.get("router").toAddress();
        address stateView = config.get("stateView").toAddress();
        address admin = config.get("admin").toAddress();
        address permit2 = config.get("permit2").toAddress();

        vm.startBroadcast();
        address quoter = address(new V4Quoter(IPoolManager(poolManager)));
        address factoryImplementation = address(new Factory());
        Factory factory =
            Factory(address(new TransparentUpgradeableProxy(factoryImplementation, msg.sender, bytes(""))));
        console.log("Factory deployed at:", address(factory));

        factory.initialize(
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
        config.set("quoter", quoter);
        vm.stopBroadcast();
    }
}
