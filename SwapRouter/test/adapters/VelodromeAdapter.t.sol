// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VelodromeAdapter} from "../../src/adapters/VelodromeAdapter.sol";
import {AdapterWrapper} from "../shared/AdapterWrapper.sol";
import {IMixedRouteQuoterV1} from "../../src/interfaces/velodrome/IMixedRouteQuoterV1.sol";

contract VelodromeAdapterTest is Test {
    uint256 fork;

    AdapterWrapper public adapter;

    function setUp() public {
        fork = vm.createFork(vm.envString("OPTIMISM_MAINNET_RPC_URL"), 136983093);

        vm.selectFork(fork);

        VelodromeAdapter velodromeAdapter = new VelodromeAdapter();

        adapter = new AdapterWrapper(address(velodromeAdapter));
    }

    function test_swapExactIn_ConcentratedLiquidityPool() public {
        address tokenIn = 0x4200000000000000000000000000000000000006; // WETH
        address tokenOut = 0x4200000000000000000000000000000000000042; // OP

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");

        deal(tokenIn, alice, amountIn);

        VelodromeAdapter.VelodromeData memory data = VelodromeAdapter.VelodromeData({
            pool: 0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            poolType: VelodromeAdapter.PoolType.CL,
            quoter: 0xFF79ec912bA114FD7989b9A2b90C65f0c1b44722,
            swapRouter: 0x0792a633F0c19c351081CF4B211F68F79bCc9676
        });

        bytes memory encodedData = abi.encode(data);

        uint256 expectedAmountOut = adapter.getAmountOut(amountIn, encodedData);

        uint256 tokenInBalanceBefore = IERC20(tokenIn).balanceOf(alice);
        uint256 tokenOutBalanceBefore = IERC20(tokenOut).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(tokenIn).approve(address(adapter), amountIn);

        uint256 amountOut = adapter.swapExactIn(tokenIn, tokenOut, amountIn, encodedData);

        vm.stopPrank();

        uint256 tokenInBalanceAfter = IERC20(tokenIn).balanceOf(alice);
        uint256 tokenOutBalanceAfter = IERC20(tokenOut).balanceOf(alice);

        assertEq(tokenInBalanceAfter, tokenInBalanceBefore - amountIn);
        assertEq(tokenOutBalanceAfter, tokenOutBalanceBefore + amountOut);

        assertEq(amountOut, expectedAmountOut);
    }

    function test_swapExactIn_VolatileV2Pool() public {
        address tokenIn = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // USDC
        address tokenOut = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db; // VELO

        uint256 amountIn = 100_000_000;

        address alice = makeAddr("alice");

        deal(tokenIn, alice, amountIn);

        VelodromeAdapter.VelodromeData memory data = VelodromeAdapter.VelodromeData({
            pool: 0xa0A215dE234276CAc1b844fD58901351a50fec8A,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            poolType: VelodromeAdapter.PoolType.V2,
            quoter: 0xFF79ec912bA114FD7989b9A2b90C65f0c1b44722,
            swapRouter: address(0)
        });

        bytes memory encodedData = abi.encode(data);

        uint256 expectedAmountOut = adapter.getAmountOut(amountIn, encodedData);

        uint256 tokenInBalanceBefore = IERC20(tokenIn).balanceOf(alice);
        uint256 tokenOutBalanceBefore = IERC20(tokenOut).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(tokenIn).approve(address(adapter), amountIn);

        uint256 amountOut = adapter.swapExactIn(tokenIn, tokenOut, amountIn, encodedData);

        vm.stopPrank();

        uint256 tokenInBalanceAfter = IERC20(tokenIn).balanceOf(alice);
        uint256 tokenOutBalanceAfter = IERC20(tokenOut).balanceOf(alice);

        assertEq(tokenInBalanceAfter, tokenInBalanceBefore - amountIn);
        assertEq(tokenOutBalanceAfter, tokenOutBalanceBefore + amountOut);

        assertEq(amountOut, expectedAmountOut);
    }

    function test_swapExactIn_StableV2Pool() public {
        address tokenIn = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // USDC
        address tokenOut = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9; // sUSD

        uint256 amountIn = 100_000_000;

        address alice = makeAddr("alice");

        deal(tokenIn, alice, amountIn);

        VelodromeAdapter.VelodromeData memory data = VelodromeAdapter.VelodromeData({
            pool: 0xbC26519f936A90E78fe2C9aA2A03CC208f041234,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            poolType: VelodromeAdapter.PoolType.V2,
            quoter: 0xFF79ec912bA114FD7989b9A2b90C65f0c1b44722,
            swapRouter: address(0)
        });

        bytes memory encodedData = abi.encode(data);

        uint256 expectedAmountOut = adapter.getAmountOut(amountIn, encodedData);

        uint256 tokenInBalanceBefore = IERC20(tokenIn).balanceOf(alice);
        uint256 tokenOutBalanceBefore = IERC20(tokenOut).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(tokenIn).approve(address(adapter), amountIn);

        uint256 amountOut = adapter.swapExactIn(tokenIn, tokenOut, amountIn, encodedData);

        vm.stopPrank();

        uint256 tokenInBalanceAfter = IERC20(tokenIn).balanceOf(alice);
        uint256 tokenOutBalanceAfter = IERC20(tokenOut).balanceOf(alice);

        assertEq(tokenInBalanceAfter, tokenInBalanceBefore - amountIn);
        assertEq(tokenOutBalanceAfter, tokenOutBalanceBefore + amountOut);

        assertEq(amountOut, expectedAmountOut);
    }
}
