// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";
import {Swap} from "../src/abstracts/Swap.sol";

contract TreasuryWalletTest is Test {
    TreasuryWallet public treasuryWallet;
    FundRaisingToken public fundRaisingToken;

    address public constant donationAddress = address(0x3);
    address public constant factoryAddress = address(0x4);
    address public constant registryAddress = address(0x5);
    address public constant nonProfitOrgAddress = address(0x6);
    address public constant router = address(0x7);
    address public constant poolManager = address(0x8);
    address public constant permit2 = address(0x9);
    address public constant positionManager = address(0x10);

    function setUp() public {
        treasuryWallet = new TreasuryWallet(
            donationAddress, factoryAddress, registryAddress, router, poolManager, permit2, positionManager
        );
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", address(0x1), address(treasuryWallet), donationAddress, factoryAddress, 1e27
        );
        vm.prank(factoryAddress);
        treasuryWallet.setFundraisingToken(address(fundRaisingToken));
        vm.stopPrank();
    }

    function testConstructorRevertsOnZeroDonationAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new TreasuryWallet(address(0), factoryAddress, registryAddress, router, poolManager, permit2, positionManager);
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new TreasuryWallet(donationAddress, address(0), registryAddress, router, poolManager, permit2, positionManager);
    }

    function testConstructorRevertsOnZeroRegistryAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new TreasuryWallet(donationAddress, address(0), registryAddress, router, poolManager, permit2, positionManager);
    }

    function testConstructorRevertsOnZeroRouterAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new TreasuryWallet(
            donationAddress, factoryAddress, registryAddress, address(0), poolManager, permit2, positionManager
        );
    }

    function testConstructorRevertsOnZeroPoolManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new TreasuryWallet(
            donationAddress, factoryAddress, registryAddress, router, address(0), permit2, positionManager
        );
    }

    function testConstructorRevertsOnZeroPermit2Address() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new TreasuryWallet(
            donationAddress, factoryAddress, registryAddress, router, poolManager, address(0), positionManager
        );
    }

    function testConstructorRevertsOnZeroPositionManagerAddress() public {
        vm.expectRevert(Swap.ZeroAddress.selector);
        new TreasuryWallet(donationAddress, factoryAddress, registryAddress, router, poolManager, permit2, address(0));
    }

    function testConstructorSetsAllAddressesCorrectly() public view {
        assertEq(treasuryWallet.donationAddress(), donationAddress);
        assertEq(treasuryWallet.factoryAddress(), factoryAddress);
        assertEq(treasuryWallet.registryAddress(), registryAddress);
        assertEq(address(treasuryWallet.router()), router);
        assertEq(address(treasuryWallet.poolManager()), poolManager);
        assertEq(address(treasuryWallet.permit2()), permit2);
        assertEq(address(treasuryWallet.positionManager()), positionManager);
    }

    function testSetFundRaisingTokenRevertsIfNotFactory() public {
        vm.expectRevert(TreasuryWallet.OnlyFactory.selector);
        treasuryWallet.setFundraisingToken(address(fundRaisingToken));
    }

    function testSetFundRaisingTokenSetsAddressCorrectlyAndEmitsFundraisingTokenSet() public {
        vm.expectEmit(true, false, false, true);
        emit TreasuryWallet.FundraisingTokenSet(address(fundRaisingToken));
        vm.prank(factoryAddress);
        treasuryWallet.setFundraisingToken(address(fundRaisingToken));
        vm.stopPrank();
        assertEq(address(treasuryWallet.fundraisingToken()), address(fundRaisingToken));
    }
}
