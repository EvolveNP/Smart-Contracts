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
import {IFactory} from "./interfaces/IFactory.sol";

contract DonationWallet is Swap {
    using StateLibrary for IPoolManager;

    IERC20 public fundraisingTokenAddress; // Address of the FundRaisingToken contract
    address public immutable owner; // Owner of the DonationWallet
    address public immutable factoryAddress; // The address of the factory contract

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
    constructor(
        address _factoryAddress,
        address _owner,
        address _router,
        address _poolManager,
        address _permit2,
        address _positionManager
    ) Swap(_router, _poolManager, _permit2, _positionManager) {
        owner = _owner;
        factoryAddress = _factoryAddress;
    }

    /**
     * @notice Swap all fundraising tokens to currency0 and transfer to non profit organization wallet
     * @dev Callbale by chainlink automation
     */
    function swapFundraisingToken() external {
        uint256 amountIn = fundraisingTokenAddress.balanceOf(address(this));

        PoolKey memory key = IFactory(factoryAddress).getPoolKey();

        uint256 amountOut = swapExactInputSingle(key, amountIn, 1);

        address currency0 = Currency.unwrap(key.currency0);
        bool success = IERC20(currency0).transfer(owner, balance);
        require(success, "Transfer failed");
        emit FundsTransferredToNonProfit(owner, balance);
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
