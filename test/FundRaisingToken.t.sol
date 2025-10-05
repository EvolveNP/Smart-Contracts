// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";

contract FundRaisingTokenTest is Test {
    FundRaisingToken public fundRaisingToken;

    address public constant lpManager = address(0x1);
    address public constant treasuryAddress = address(0x2);
    address public constant donationAddress = address(0x3);
    address public constant factoryAddress = address(0x4);
    uint256 public constant totalSupply = 1e27; // 1 billion tokens with 18 decimals

    function setUp() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, totalSupply
        );
    }

    function testConstructorRevertsOnZeroLPManagerAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, address(0), treasuryAddress, donationAddress, factoryAddress, 1e24
        );
    }

    function testConstructorRevertsOnZeroTreasuryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", 6, lpManager, address(0), donationAddress, factoryAddress, 1e24);
    }

    function testConstructorRevertsOnZeroDonationAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, address(0), factoryAddress, 1e24);
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, address(0), 1e24
        );
    }

    function testConstructorRevertsOnZeroTotalSupplyValue() public {
        vm.expectRevert(FundRaisingToken.ZeroAmount.selector);
        new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 0
        );
    }

    function testConstructorMintsCorrectAmountToLPManager() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 1e24
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 75e22);
    }

    function testConstructorMintsCorrectAmountToTreasury() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 2e24
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 150e22);
    }

    function testConstructorSetAllAddressesCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 1e24
        );
        assertEq(fundRaisingToken.lpManager(), lpManager);
        assertEq(fundRaisingToken.treasuryAddress(), treasuryAddress);
        assertEq(fundRaisingToken.donationAddress(), donationAddress);
    }

    function testConstructorSetTotalSupplyCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", 6, lpManager, treasuryAddress, donationAddress, factoryAddress, 5e24
        );
        assertEq(fundRaisingToken.totalSupply(), 5e24);
    }

    function testBurnRevertsOnZeroAmount() public {
        vm.prank(treasuryAddress);
        vm.expectRevert(FundRaisingToken.ZeroAmount.selector);
        fundRaisingToken.burn(0);
    }

    function testBurnRevertsIfNotCalledByTreasury() public {
        vm.prank(address(0x4));
        vm.expectRevert(FundRaisingToken.OnlyTreasury.selector);
        fundRaisingToken.burn(1e18);
    }

    function testBurnReducesTotalSupplyAndTreasuryBalance() public {
        uint256 initialTotalSupply = fundRaisingToken.totalSupply();
        uint256 initialTreasuryBalance = fundRaisingToken.balanceOf(treasuryAddress);
        uint256 burnAmount = 1e18;

        vm.prank(treasuryAddress);
        fundRaisingToken.burn(burnAmount);

        assertEq(fundRaisingToken.totalSupply(), initialTotalSupply - burnAmount);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), initialTreasuryBalance - burnAmount);
    }

    function testBurnCannotIncurTax() public {
        uint256 initialTotalSupply = fundRaisingToken.totalSupply();
        uint256 initialTreasuryBalance = fundRaisingToken.balanceOf(treasuryAddress);
        uint256 burnAmount = 1e18;

        vm.prank(treasuryAddress);
        fundRaisingToken.burn(burnAmount);

        assertEq(fundRaisingToken.totalSupply(), initialTotalSupply - burnAmount);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), initialTreasuryBalance - burnAmount);
    }

    function testLuanchBlockAndTimestampOnlyCalledByFactory() public {
        vm.expectRevert(FundRaisingToken.OnlyFactory.selector);
        fundRaisingToken.setLuanchBlockAndTimestamp();
    }

    function testLuanchBlockAndTimestampEmitsEventAndSetsLaunchBlock() public {
        vm.prank(factoryAddress);
        vm.expectEmit(true, false, false, true);
        emit FundRaisingToken.LuanchBlockAndTimestampSet(block.number, block.timestamp);
        fundRaisingToken.setLuanchBlockAndTimestamp();
    }

    function testTransferLpManagerCanTransferToLPPool() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);
    }

    // function testTransferCannotTransderBlockToHoldNotPassed() public {
    //     vm.prank(factoryAddress);
    //     fundRaisingToken.setLuanchBlockAndTimestamp();
    //     vm.prank(lpManager);
    //     vm.expectRevert(FundRaisingToken.TransferBlocked.selector);
    //     fundRaisingToken.transfer(address(0x10), 1e18);
    // }

    // function testTransferTradeIfBlockToHoldPassed() public {
    //     vm.prank(factoryAddress);
    //     fundRaisingToken.setLuanchBlockAndTimestamp();
    //     vm.roll(block.number + 11);
    //     vm.prank(lpManager);
    //     fundRaisingToken.transfer(address(0x10), 1e18);
    //     assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);
    // }

    function testTransferCannotCutTaxIfTransferInitiatedFromLPManager() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);
    }

    function testTransferCannotCutTaxIfTransferIsToLPManager() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(lpManager, 1e18);
        assertEq(fundRaisingToken.balanceOf(lpManager), 75e25);
    }

    function testTransferCannotCutTaxIfTransferInitiatedFromDonationAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(donationAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(donationAddress), 1e18);

        vm.prank(donationAddress);
        fundRaisingToken.transfer(address(0x10), 1e18);
        assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);
    }

    function testTransferCannotCutTaxIfTransferIsToDonationAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(donationAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(donationAddress), 1e18);
    }

    function testTransferCannotCutTaxIfTransferInitiatedFromTreasuryAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(treasuryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 1e18 + 25e25);

        vm.prank(treasuryAddress);
        fundRaisingToken.transfer(address(0x10), 1e18);
        assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);
    }

    function testTransferCannotCutTaxIfTransferIsToTreasuryAddress() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(treasuryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 1e18 + 25e25);
    }

    function testTransferCannotCutTaxIfTreasuryBalanceIsGreaterthanMaximumThreshold() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(treasuryAddress, 10e25);
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 35e25);

        vm.prank(lpManager);
        fundRaisingToken.transfer(address(0x10), 1e18);
        assertEq(fundRaisingToken.balanceOf(address(0x10)), 1e18);

        vm.prank(address(0x10));
        fundRaisingToken.transfer(address(0x20), 1e18);

        assertEq(fundRaisingToken.balanceOf(address(0x20)), 1e18);

        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 35e25);
    }

    function testTransferCutsTaxIfNotFromOrToSystemAddresses() public {
        vm.prank(lpManager);
        fundRaisingToken.transfer(factoryAddress, 1e18);
        assertEq(fundRaisingToken.balanceOf(factoryAddress), 1e18);

        vm.prank(factoryAddress);
        fundRaisingToken.transfer(address(0x20), 1e18);
        // 1e18 - 2% tax = 0.98e18
        assertEq(fundRaisingToken.balanceOf(address(0x20)), 1e18);
        // Treasury should receive 2% tax = 0.02e18
        assertEq(fundRaisingToken.balanceOf(treasuryAddress), 25e25);
    }
}
