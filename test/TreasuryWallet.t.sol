// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TreasuryWallet} from "../src/TreasuryWallet.sol";

contract TreasuryWalletTest is Test {
    TreasuryWallet public treasuryWallet;
    FundRaisingToken public fundRaisingToken;

    address public constant donationAddress = address(0x3);
    address public constant factoryAddress = address(0x4);
    address public constant registryAddress = address(0x5);

    function setUp() public {
        treasuryWallet = new TreasuryWallet(donationAddress, factoryAddress, registryAddress);
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", address(0x1), address(treasuryWallet), donationAddress, 1e27
        );
        vm.prank(factoryAddress);
        treasuryWallet.setFundraisingToken(address(fundRaisingToken));
        vm.stopPrank();
    }

    function testConstructorRevertsOnZeroDonationAddress() public {
        vm.expectRevert(bytes("Zero address"));
        new TreasuryWallet(address(0), factoryAddress, registryAddress);
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(bytes("Zero address"));
        new TreasuryWallet(donationAddress, address(0), registryAddress);
    }

    function testConstructorRevertsOnZeroRegistryAddress() public {
        vm.expectRevert(bytes("Zero address"));
        new TreasuryWallet(donationAddress, address(0), registryAddress);
    }

    function testConstructorSetsAllAddressesCorrectly() public view {
        assertEq(treasuryWallet.donationAddress(), donationAddress);
        assertEq(treasuryWallet.factoryAddress(), factoryAddress);
        assertEq(treasuryWallet.registryAddress(), registryAddress);
    }

    function testSetFundRaisingTokenRevertsIfNotFactory() public {
        vm.expectRevert(bytes("Only factory"));
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

    function testTransferFundsRevertsIfNotRegistry() public {
        vm.expectRevert(bytes("Only registry"));
        treasuryWallet.transferFunds();
    }

    function testTransferBlocked() public {
        vm.startPrank(registryAddress);
        vm.expectRevert(bytes("Transfer blocked"));

        //  uint256 amountToTransferAndBurn = fundRaisingToken.totalSupply() * 2e16 / 1e18; // 2% of total supply
        // emit TreasuryWallet.FundTransferredToDonationWallet(amountToTransferAndBurn);
        treasuryWallet.transferFunds();
        //  assertEq(fundRaisingToken.balanceOf(donationAddress), amountToTransferAndBurn);
        vm.stopPrank();
    }
}
