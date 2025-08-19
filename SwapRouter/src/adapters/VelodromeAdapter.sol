// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMixedRouteQuoterV1} from "../interfaces/velodrome/IMixedRouteQuoterV1.sol";
import {IRouter} from "../interfaces/velodrome/IRouter.sol";
import {IPool} from "../interfaces/velodrome/IPool.sol";
import {ICLPool} from "../interfaces/velodrome/ICLPool.sol";
import {IAdapter} from "../interfaces/IAdapter.sol";

contract VelodromeAdapter {
    using SafeERC20 for IERC20;

    enum PoolType {
        V2,
        CL
    }

    struct VelodromeData {
        PoolType poolType;
        address pool;
        address tokenIn;
        address tokenOut;
        address quoter;
        // swapRouter is only used for CL pools, can be set to address(0) for V2 pools
        address swapRouter;
    }

    function swapExactIn(uint256 amountIn, bytes calldata data) external payable returns (uint256 amountOut) {
        VelodromeData memory velodromeData = abi.decode(data, (VelodromeData));

        if (velodromeData.poolType == PoolType.V2) {
            amountOut = getAmountOut(amountIn, data);
            _swapV2Pool(velodromeData.pool, velodromeData.tokenIn, amountIn, amountOut);
        } else {
            amountOut = _swapCLPool(velodromeData, amountIn);
        }
    }

    function getAmountOut(uint256 amountIn, bytes calldata data) public returns (uint256 amountOut) {
        VelodromeData memory velodromeData = abi.decode(data, (VelodromeData));

        int24 tickSpacing = _tickSpacing(velodromeData.poolType, velodromeData.pool);

        bytes memory path = abi.encodePacked(velodromeData.tokenIn, tickSpacing, velodromeData.tokenOut);

        (amountOut,,,) = IMixedRouteQuoterV1(velodromeData.quoter).quoteExactInput(path, amountIn);
    }

    function getAmountIn(uint256, bytes calldata) external pure returns (uint256) {
        revert("getAmountIn not supported for Velodrome");
    }

    function _swapV2Pool(address pool, address tokenIn, uint256 amountIn, uint256 amountOut) internal {
        IERC20(tokenIn).safeTransfer(pool, amountIn);

        bool zeroForOne = IPool(pool).token0() == tokenIn;

        IPool(pool).swap(zeroForOne ? 0 : amountOut, zeroForOne ? amountOut : 0, address(this), "");
    }

    function _swapCLPool(VelodromeData memory velodromeData, uint256 amountIn) internal returns (uint256 amountOut) {
        IRouter.ExactInputSingleParams memory params = IRouter.ExactInputSingleParams({
            tokenIn: velodromeData.tokenIn,
            tokenOut: velodromeData.tokenOut,
            tickSpacing: _tickSpacing(velodromeData.poolType, velodromeData.pool),
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });

        IERC20(velodromeData.tokenIn).forceApprove(velodromeData.swapRouter, amountIn);

        amountOut = IRouter(velodromeData.swapRouter).exactInputSingle(params);
    }

    function _tickSpacing(PoolType poolType, address pool) internal view returns (int24) {
        if (poolType == PoolType.V2) {
            (,,,, bool stable,,) = IPool(pool).metadata();

            // For volatile V2 pairs, use 4194304
            // For stable V2 pairs, use 2097152
            // Rationale: https://optimistic.etherscan.io/address/0xFF79ec912bA114FD7989b9A2b90C65f0c1b44722#writeContract#F1
            return stable ? int24(2097152) : int24(4194304);
        } else {
            return ICLPool(pool).tickSpacing();
        }
    }
}
