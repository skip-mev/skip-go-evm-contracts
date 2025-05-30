// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IQuoter} from "../interfaces/uniswapv3/IQuoter.sol";
import {ISwapRouter} from "../interfaces/uniswapv3/ISwapRouter.sol";

contract UniswapV3Adapter {
    struct UniswapV3Data {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address quoter;
        address swapRouter;
    }

    function swapExactIn(uint256 amountIn, bytes calldata data) external payable returns (uint256 amountOut) {
        UniswapV3Data memory uniswapV3Data = abi.decode(data, (UniswapV3Data));

        IERC20(uniswapV3Data.tokenIn).approve(uniswapV3Data.swapRouter, amountIn);

        amountOut = ISwapRouter(uniswapV3Data.swapRouter).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: uniswapV3Data.tokenIn,
                tokenOut: uniswapV3Data.tokenOut,
                fee: uniswapV3Data.fee,
                recipient: address(this),
                deadline: block.timestamp + 10 minutes,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            })
        );

        return amountOut;
    }

    function getAmountOut(uint256 amountIn, bytes calldata data) external view returns (uint256 amountOut) {
        UniswapV3Data memory uniswapV3Data = abi.decode(data, (UniswapV3Data));

        bytes memory path = abi.encodePacked(uniswapV3Data.tokenIn, uniswapV3Data.fee, uniswapV3Data.tokenOut);

        (amountOut,,,) = IQuoter(uniswapV3Data.quoter).quoteExactInput(path, amountIn);

        return amountOut;
    }

    function getAmountIn(uint256 amountOut, bytes calldata data) external view returns (uint256 amountIn) {
        UniswapV3Data memory uniswapV3Data = abi.decode(data, (UniswapV3Data));

        bytes memory path = abi.encodePacked(uniswapV3Data.tokenOut, uniswapV3Data.fee, uniswapV3Data.tokenIn);

        (amountIn,,,) = IQuoter(uniswapV3Data.quoter).quoteExactOutput(path, amountOut);
    }
}
