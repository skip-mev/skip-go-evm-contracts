// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {SkipGoSwapRouter} from "../src/SkipGoSwapRouter.sol";
import {UniswapV2Adapter} from "../src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "../src/adapters/UniswapV3Adapter.sol";

contract SwapRouterDeploy is Script {
    function run() external {
        vm.startBroadcast();

        address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        SkipGoSwapRouter router = new SkipGoSwapRouter(weth);

        UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();

        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V2, address(uniswapV2Adapter));
        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V3, address(uniswapV3Adapter));

        vm.stopBroadcast();

        console.log("SkipGoSwapRouter deployed at", address(router));
    }
}
