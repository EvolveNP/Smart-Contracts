// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {Swap} from "../src/abstracts/Swap.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TreasuryWalletTest is Test {
    TreasuryWallet public treasuryWallet;
    FundRaisingToken public fundRaisingToken;

    address constant DONATION = address(0x1111);
    address constant FACTORY = address(0x2222);
    address constant REGISTRY = address(0x3333);
    address constant ROUTER = address(0x4444);
    address constant POOL_MANAGER = address(0x5555);
    address constant PERMIT2 = address(0x6666);
    address constant POSITION_MANAGER = address(0x7777);
    address constant QUOTER = address(0x8888);

    uint256 constant MIN_HEALTH = 100;
    uint256 constant TRANSFER_INTERVAL = 3600;
    uint256 constant MIN_LP_HEALTH = 30 days;
    int24 constant DEFAULT_TICK = 60;

    uint256 internal constant MULTIPLIER = 1e18;

    address treasuryBeacon;

    function setUp() public {
        address treasuryImplementation = address(new TreasuryWallet());
        treasuryBeacon = address(new UpgradeableBeacon(treasuryImplementation, msg.sender));
        console.log(treasuryBeacon, "beacon");
        treasuryWallet = TreasuryWallet(address(new BeaconProxy(treasuryBeacon, "")));
        console.log(address(treasuryWallet), "address");
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, address(0x1), address(treasuryWallet), DONATION, FACTORY, 1e27, 2e16, 30e16
        );
    }

    function testRevertOnZeroDonationAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            address(0),
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroFactoryAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            address(0),
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroRegistryAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            address(0),
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroRouterAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            address(0),
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroPoolManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            address(0),
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroPermit2Address() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            address(0),
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroPositionManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            address(0),
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroQuoterAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            address(0),
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testRevertOnZeroFundraisingTokenAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(0)
        );
    }

    function testRevertOnZeroTransferInterval() public {
        vm.expectRevert(Swap.ZeroAmount.selector); // should revert due to nonZeroAddress modifier
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            0,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testCannotInitializeTwice() public {
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );

        vm.expectRevert(Initializable.InvalidInitialization.selector); // expected since initialize should only be callable once
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );
    }

    function testInitializeSetsValuesCorrectly() public {
        treasuryWallet.initialize(
            DONATION,
            FACTORY,
            REGISTRY,
            ROUTER,
            POOL_MANAGER,
            PERMIT2,
            POSITION_MANAGER,
            QUOTER,
            MIN_HEALTH,
            TRANSFER_INTERVAL,
            MIN_LP_HEALTH,
            DEFAULT_TICK,
            address(fundRaisingToken)
        );

        assertEq(treasuryWallet.donationAddress(), DONATION);
        assertEq(treasuryWallet.factoryAddress(), FACTORY);
        assertEq(treasuryWallet.registryAddress(), REGISTRY);
        assertEq(treasuryWallet.minimumHealthThreshhold(), MIN_HEALTH);
        assertEq(treasuryWallet.transferInterval(), TRANSFER_INTERVAL);
    }
}
