// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Swap} from "./abstracts/Swap.sol";

contract DonationWallet is Swap {
    using StateLibrary for IPoolManager;

    IERC20 public fundraisingTokenAddress; // Address of the FundRaisingToken contract
    address public immutable owner; // Owner of the DonationWallet
    address public immutable factoryAddress; // The address of the factory contract

    UniversalRouter public immutable router;
    IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;

    event FundraisingTokenAddressSet(address fundraisingToken);
    event FundsTransferredToNonProfit(address recipient, uint256 amount);

    modifier onlyFactory(address _addr) {
        require(_addr == factoryAddress, "Only by factory");
        _;
    }

    /**
     *
     * @param _factoryAddress The address of the factory contract
     * @param _owner The wallet address of non profit organization that receives the donation
     */
    constructor(address _factoryAddress, address _owner, address _router, address _poolManager, address _permit2)
        Swap(_router, _poolManager, _permit2)
    {
        owner = _owner;
        factoryAddress = _factoryAddress;
    }

    /**
     * TODO
     */
    function transferAsset() external view {
        require(fundraisingTokenAddress.balanceOf(address(this)) > 0, "No tokens to transfer");
    }

    /**
     * TODO
     */
    function swapFundraisingToken() external {
        swapExactInputSingle(fundraisingTokenAddress.balanceOf(address(this)), 1);

        uint256 balance = IERC20(key.currency1).balanceOf(address(this));

        IERC20(key.currency1).transfer(owner, balance);

        emit FundsTransferredToNonProfit(owner, balance);
    }

    function approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) external {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
    }

    /**
     * @notice Set the address of the fundraising token
     * @param _fundraisingToken The address of the fundraising token
     * @dev Only set vai factory contract
     */
    function setFundraisingTokenAddress(address _fundraisingToken) external onlyFactory(msg.sender) {
        fundraisingTokenAddress = IERC20(_fundraisingToken);
        emit FundraisingTokenAddressSet(_fundraisingToken);
    }
}
