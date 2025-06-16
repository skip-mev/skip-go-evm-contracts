// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {SkipGoSwapRouter} from "../src/SkipGoSwapRouter.sol";
import {UniswapV2Adapter} from "../src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "../src/adapters/UniswapV3Adapter.sol";
import {VelodromeAdapter} from "../src/adapters/VelodromeAdapter.sol";

contract SwapRouterDeploy is Script {
    function run() external {
        // vm.startBroadcast();

        // address weth = getWethAddress(block.chainid);

        // SkipGoSwapRouter routerImpl = new SkipGoSwapRouter();

        // ERC1967Proxy routerProxy =
        //     new ERC1967Proxy(address(routerImpl), abi.encodeWithSignature("initialize(address)", weth));

        // SkipGoSwapRouter router = SkipGoSwapRouter(payable(address(routerProxy)));

        // UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
        // UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();
        // VelodromeAdapter velodromeAdapter = new VelodromeAdapter();

        // router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V2, address(uniswapV2Adapter));
        // router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V3, address(uniswapV3Adapter));
        // router.addAdapter(SkipGoSwapRouter.ExchangeType.VELODROME, address(velodromeAdapter));

        // vm.stopBroadcast();

        // console.log("SkipGoSwapRouter deployed at", address(router));

        SkipGoSwapRouter router = SkipGoSwapRouter(payable(0xAe27D9FD07cBB9c6b6D57f2cc08EB6EF43C09B01));

        VelodromeAdapter.VelodromeData memory data = VelodromeAdapter.VelodromeData({
            poolType: VelodromeAdapter.PoolType.CL,
            pool: 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59,
            tokenIn: 0x4200000000000000000000000000000000000006,
            tokenOut: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            quoter: 0x0A5aA5D3a4d28014f967Bf0f29EAA3FF9807D5c6,
            swapRouter: 0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5
        });

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](1);
        hops[0] = SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.VELODROME, data: abi.encode(data)});

        uint256 amountIn = 1000000000000000000;

        uint256 amountOut = router.getAmountOut(amountIn, hops);

        console.log("Amount out", amountOut);
    }

    function getWethAddress(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        }
        if (chainId == 43114) {
            return address(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
        }
        if (chainId == 42161) {
            return address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        }
        if (chainId == 56) {
            return address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
        }
        if (chainId == 8453) {
            return address(0x4200000000000000000000000000000000000006);
        }
        if (chainId == 81457) {
            return address(0x4300000000000000000000000000000000000004);
        }
        if (chainId == 42220) {
            // this is correct
            return address(0);
        }
        if (chainId == 10) {
            return address(0x4200000000000000000000000000000000000006);
        }
        if (chainId == 137) {
            return address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
        }

        revert("Chain not supported");
    }
}
