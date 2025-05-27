// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IAdapter {
    function swapExactIn(uint256 amountIn, bytes calldata data) external returns (uint256 amountOut);

    function getAmountOut(uint256 amountIn, bytes calldata data) external view returns (uint256 amountOut);

    function getAmountIn(uint256 amountOut, bytes calldata data) external view returns (uint256 amountIn);
}
