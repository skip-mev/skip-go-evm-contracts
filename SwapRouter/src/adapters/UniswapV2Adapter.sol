// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV2Pair} from "../interfaces/uniswapv2/IUniswapV2Pair.sol";

contract UniswapV2Adapter {
    struct UniswapV2Data {
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 fee;
    }

    function swapExactIn(uint256 amountIn, bytes calldata data) external payable returns (uint256 amountOut) {
        UniswapV2Data memory uniswapV2Data = abi.decode(data, (UniswapV2Data));

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(uniswapV2Data.pool).getReserves();

        bool zeroToOne = uniswapV2Data.tokenIn == IUniswapV2Pair(uniswapV2Data.pool).token0();

        (uint256 reserveIn, uint256 reserveOut) = zeroToOne ? (reserve0, reserve1) : (reserve1, reserve0);

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut, uniswapV2Data.fee);

        IERC20(uniswapV2Data.tokenIn).transfer(uniswapV2Data.pool, amountIn);

        zeroToOne
            ? IUniswapV2Pair(uniswapV2Data.pool).swap(0, amountOut, address(this), "")
            : IUniswapV2Pair(uniswapV2Data.pool).swap(amountOut, 0, address(this), "");
    }

    function getAmountOut(uint256 amountIn, bytes calldata data) external view returns (uint256 amountOut) {
        UniswapV2Data memory uniswapV2Data = abi.decode(data, (UniswapV2Data));

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(uniswapV2Data.pool).getReserves();

        bool zeroToOne = uniswapV2Data.tokenIn == IUniswapV2Pair(uniswapV2Data.pool).token0();

        (uint256 reserveIn, uint256 reserveOut) = zeroToOne ? (reserve0, reserve1) : (reserve1, reserve0);

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut, uniswapV2Data.fee);
    }

    function getAmountIn(uint256 amountOut, bytes calldata data) external view returns (uint256 amountIn) {
        UniswapV2Data memory uniswapV2Data = abi.decode(data, (UniswapV2Data));

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(uniswapV2Data.pool).getReserves();

        bool zeroToOne = uniswapV2Data.tokenIn == IUniswapV2Pair(uniswapV2Data.pool).token0();

        (uint256 reserveIn, uint256 reserveOut) = zeroToOne ? (reserve0, reserve1) : (reserve1, reserve0);

        amountIn = _getAmountIn(amountOut, reserveIn, reserveOut, uniswapV2Data.fee);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 fee)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * (10000 - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 fee)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * (10000 - fee);
        amountIn = (numerator / denominator) + 1;
    }
}
