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

        address routerAddress = getRouterAddress(block.chainid);

        SkipGoSwapRouter router = SkipGoSwapRouter(payable(routerAddress));

        SkipGoSwapRouter newImpl = new SkipGoSwapRouter();

        router.upgradeToAndCall(address(newImpl), bytes(""));

        vm.stopBroadcast();
    }

    function getRouterAddress(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return address(0xd1eE705D774d59541d3D395e72A16E48389DF7C7);
        }
        if (chainId == 43114) {
            return address(0xfF19fcC8563Aef3a1a83A2F52AeF9AE41D767333);
        }
        if (chainId == 42161) {
            return address(0xA307099736ff10f6A639D8a00F3C0AC62E10424a);
        }
        if (chainId == 56) {
            return address(0xbC4bdEB1E85C62f5Da9cb732a5209408db7B4769);
        }
        if (chainId == 8453) {
            return address(0xD57611Dd97eacb7AE19aE5d789e943d07f4dfa4f);
        }
        if (chainId == 81457) {
            return address(0x32Fb43172c0afB63770372fDe4A84E9b827Ec903);
        }
        if (chainId == 42220) {
            return address(0xF29F1f9f06054F23B5bC9De9bC5017bff8bF1a05);
        }
        if (chainId == 10) {
            return address(0xc352fB0E5fC310FCbfD736542d45Efa27B9E1Cae);
        }
        if (chainId == 137) {
            return address(0x8A68Dd4b423Ef7568d0cdf3bB8E4863Ca1041a9e);
        }

        revert("Chain not supported");
    }
}
