// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {SkipGoSwapRouter} from "../src/SkipGoSwapRouter.sol";
import {UniswapV2Adapter} from "../src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "../src/adapters/UniswapV3Adapter.sol";

contract SwapRouterDeploy is Script {
    function run() external {
        vm.startBroadcast();

        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        SkipGoSwapRouter router = new SkipGoSwapRouter(weth);

        UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();

        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V2, address(uniswapV2Adapter));
        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V3, address(uniswapV3Adapter));

        vm.stopBroadcast();

        console.log("SkipGoSwapRouter deployed at", address(router));
    }
}
