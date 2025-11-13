// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface ITreasury {
    function isTreasuryPaused() external view returns (bool);
    function registryAddress() external view returns (address);
}
