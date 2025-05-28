// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {SkipGoSwapRouter} from "../src/SkipGoSwapRouter.sol";
import {UniswapV2Adapter} from "../src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "../src/adapters/UniswapV3Adapter.sol";

contract SwapRouterDeploy is Script {
    function run() external {
        vm.startBroadcast();

        SkipGoSwapRouter router = SkipGoSwapRouter(0xa11CC0eFb1B3AcD95a2B8cd316E8c132E16048b5);

        UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();

        router.addAdapter(1, address(uniswapV2Adapter));
        router.addAdapter(2, address(uniswapV3Adapter));

        vm.stopBroadcast();

        console.log("SkipGoSwapRouter deployed at", address(router));
    }
}
