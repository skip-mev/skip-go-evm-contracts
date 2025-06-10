// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IMixedRouteQuoterV1 {
    function quoteExactInput(bytes memory path, uint256 amountIn)
        external
        returns (
            uint256 amountOut,
            uint160[] memory v3SqrtPriceX96AfterList,
            uint32[] memory v3InitializedTicksCrossedList,
            uint256 v3SwapGasEstimate
        );

    function factory() external view returns (address);
}
