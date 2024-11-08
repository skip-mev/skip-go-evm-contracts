// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {ISwapRouter02} from "./interfaces/ISwapRouter02.sol";
import {IFastTransferGateway} from "./interfaces/IFastTransferGateway.sol";

contract GoFastHandler is Ownable {
    using SafeERC20 for IERC20;

    ISwapRouter02 public swapRouter;
    IFastTransferGateway public fastTransferGateway;

    constructor(address _swapRouter, address _fastTransferGateway) {
        swapRouter = ISwapRouter02(_swapRouter);
        fastTransferGateway = IFastTransferGateway(_fastTransferGateway);
    }

    function setSwapRouter(address _swapRouter) public onlyOwner {
        swapRouter = ISwapRouter02(_swapRouter);
    }

    function setFastTransferGateway(address _fastTransferGateway) public onlyOwner {
        fastTransferGateway = IFastTransferGateway(_fastTransferGateway);
    }

    function swapAndSubmitOrder(
        address tokenIn,
        uint256 swapAmountIn,
        bytes memory swapCalldata,
        uint256 executionFeeAmount,
        uint256 solverFeeBPS,
        bytes32 sender,
        bytes32 recipient,
        uint32 destinationDomain,
        uint64 timeoutTimestamp,
        bytes calldata destinationCalldata
    ) public payable returns (bytes32) {
        require(executionFeeAmount != 0, "execution fee cannot be zero");
        require(solverFeeBPS != 0, "solver fee cannot be zero");

        uint256 swapAmountOut;
        uint256 swapAmountOutAfterFee;

        {
            swapAmountOut = _swap(tokenIn, swapAmountIn, swapCalldata);

            uint256 solverFeeAmount = (swapAmountOut * solverFeeBPS) / 10000;
            uint256 totalFee = executionFeeAmount + solverFeeAmount;

            require(swapAmountOut >= totalFee, "amount received from swap is less than fee");

            // this is the amount that the recipient will receive on the destination chain
            swapAmountOutAfterFee = swapAmountOut - totalFee;
        }

        bytes32 orderId = fastTransferGateway.submitOrder(
            sender,
            recipient,
            swapAmountOut,
            swapAmountOutAfterFee,
            destinationDomain,
            timeoutTimestamp,
            destinationCalldata
        );

        _refundToken(tokenIn);

        return orderId;
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

    function _tokenBalance(address token) internal view returns (uint256) {
        if (token != address(0)) {
            return IERC20(token).balanceOf(address(this));
        } else {
            return address(this).balance;
        }
    }

    function _refundToken(address token) internal {
        uint256 amount = _tokenBalance(token);
        if (token != address(0)) {
            IERC20(token).safeTransfer(msg.sender, amount);
        } else {
            payable(msg.sender).transfer(amount);
        }
    }
}
