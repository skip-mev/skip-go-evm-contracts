// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UniswapV3Adapter} from "../../src/adapters/UniswapV3Adapter.sol";
import {AdapterWrapper} from "../shared/AdapterWrapper.sol";

contract UniswapV2AdapterTest is Test {
    uint256 mainnetFork;

    AdapterWrapper public adapter;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("ETHEREUM_MAINNET_RPC_URL"), 22288910);

        vm.selectFork(mainnetFork);

        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();

        adapter = new AdapterWrapper(address(uniswapV3Adapter));
    }

    function test_swapExactIn() public {
        address tokenIn = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address tokenOut = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");

        deal(tokenIn, alice, amountIn);

        UniswapV3Adapter.UniswapV3Data memory data = UniswapV3Adapter.UniswapV3Data({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 3000,
            quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
            swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
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
