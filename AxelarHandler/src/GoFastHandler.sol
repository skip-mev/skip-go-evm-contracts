// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter02} from "./interfaces/ISwapRouter02.sol";
import {IFastTransferGateway} from "./interfaces/IFastTransferGateway.sol";

contract GoFastHandler {
    using SafeERC20 for IERC20;

    ISwapRouter02 public swapRouter;
    IFastTransferGateway public fastTransferGateway;

    constructor(address _swapRouter, address _fastTransferGateway) {
        swapRouter = ISwapRouter02(_swapRouter);
        fastTransferGateway = IFastTransferGateway(_fastTransferGateway);
    }

    function swapAndSubmitOrder(
        address tokenIn,
        uint256 swapAmountIn,
        bytes memory swapCalldata,
        uint256 feeAmount,
        bytes32 sender,
        bytes32 recipient,
        uint32 destinationDomain,
        uint64 timeoutTimestamp,
        bytes calldata destinationCalldata
    ) public payable returns (bytes32) {
        require(feeAmount != 0, "fast transfer fee cannot be zero");

        uint256 swapAmountOut = _swap(tokenIn, swapAmountIn, swapCalldata);

        require(swapAmountOut >= feeAmount, "amount received from swap is less than fast transfer fee");

        // this is the amount that the recipient will receive on the destination chain
        uint256 swapAmountOutAfterFee = swapAmountOut - feeAmount;

        return fastTransferGateway.submitOrder(
            sender,
            recipient,
            swapAmountOut,
            swapAmountOutAfterFee,
            destinationDomain,
            timeoutTimestamp,
            destinationCalldata
        );
    }

    function _swap(address tokenIn, uint256 amountIn, bytes memory swapCalldata) internal returns (uint256 amountOut) {
        address tokenOut = fastTransferGateway.token();

        uint256 tokenOutBalanceBefore = IERC20(tokenOut).balanceOf(address(this));

        if (tokenIn != address(0)) {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

            IERC20(tokenIn).safeApprove(address(swapRouter), amountIn);
        }

        (bool success,) = address(swapRouter).call{value: msg.value}(swapCalldata);
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - tokenOutBalanceBefore;
    }
}
