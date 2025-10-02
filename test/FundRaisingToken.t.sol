// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {FundRaisingToken} from "../src/FundRaisingToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FundRaisingTokenTest is Test {
    FundRaisingToken public fundRaisingToken;

    address public constant lpManager = address(0x1);
    address public constant treasuryAddress = donationAddress;
    address public constant donationAddress = address(0x3);
    address public constant factoryAddress = address(0x4);
    uint256 public constant totalSupply = 1e27; // 1 billion tokens with 18 decimals

    function setUp() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", lpManager, treasuryAddress, donationAddress, factoryAddress, totalSupply
        );
    }

    function testConstructorRevertsOnZeroLPManagerAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new FundRaisingToken(
            "FundRaisingToken", "FRT", address(0), treasuryAddress, donationAddress, factoryAddress, 1e24
        );
    }

    function testConstructorRevertsOnZeroTreasuryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", lpManager, address(0), donationAddress, factoryAddress, 1e24);
    }

    function testConstructorRevertsOnZeroDonationAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", lpManager, treasuryAddress, address(0), factoryAddress, 1e24);
    }

    function testConstructorRevertsOnZeroFactoryAddress() public {
        vm.expectRevert(FundRaisingToken.ZeroAddress.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", lpManager, treasuryAddress, donationAddress, address(0), 1e24);
    }

    function testConstructorRevertsOnZeroTotalSupplyValue() public {
        vm.expectRevert(FundRaisingToken.ZeroAmount.selector);
        new FundRaisingToken("FundRaisingToken", "FRT", lpManager, treasuryAddress, donationAddress, factoryAddress, 0);
    }

    function testConstructorMintsCorrectAmountToLPManager() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", lpManager, treasuryAddress, donationAddress, factoryAddress, 1e24
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 75e22);
    }

    function testConstructorMintsCorrectAmountToTreasury() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", lpManager, treasuryAddress, donationAddress, factoryAddress, 2e24
        );
        assertEq(fundRaisingToken.balanceOf(lpManager), 150e22);
    }

    function testConstructorSetAllAddressesCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", lpManager, treasuryAddress, donationAddress, factoryAddress, 1e24
        );
        assertEq(fundRaisingToken.lpManager(), lpManager);
        assertEq(fundRaisingToken.treasuryAddress(), treasuryAddress);
        assertEq(fundRaisingToken.donationAddress(), donationAddress);
    }

    function testConstructorSetTotalSupplyCorrectly() public {
        fundRaisingToken = new FundRaisingToken(
            "FundRaisingToken", "FRT", lpManager, treasuryAddress, donationAddress, factoryAddress, 5e24
        );
        assertEq(fundRaisingToken.totalSupply(), 5e24);
    }

    function testOwnerIsLPManager() public view {
        assertEq(fundRaisingToken.owner(), lpManager);
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

    function testTransferCannotTrade() public {}
}
