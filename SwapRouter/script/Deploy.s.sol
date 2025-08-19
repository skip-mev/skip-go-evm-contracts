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
        vm.startBroadcast();

        address weth = getWethAddress(block.chainid);

        SkipGoSwapRouter routerImpl = new SkipGoSwapRouter();

        ERC1967Proxy routerProxy =
            new ERC1967Proxy(address(routerImpl), abi.encodeWithSignature("initialize(address)", weth));

        SkipGoSwapRouter router = SkipGoSwapRouter(payable(address(routerProxy)));

        UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();
        VelodromeAdapter velodromeAdapter = new VelodromeAdapter();

        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V2, address(uniswapV2Adapter));
        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V3, address(uniswapV3Adapter));
        router.addAdapter(SkipGoSwapRouter.ExchangeType.VELODROME, address(velodromeAdapter));

        vm.stopBroadcast();

        console.log("SkipGoSwapRouter deployed at", address(router));
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
            return address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        }

        revert("Chain not supported");
    }
}
