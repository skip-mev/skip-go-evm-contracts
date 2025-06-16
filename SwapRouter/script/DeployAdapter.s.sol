// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {SkipGoSwapRouter} from "../src/SkipGoSwapRouter.sol";

import {UniswapV2Adapter} from "../src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "../src/adapters/UniswapV3Adapter.sol";
import {VelodromeAdapter} from "../src/adapters/VelodromeAdapter.sol";

contract DeployAdapter is Script {
    function run(string memory _dexType) external {
        console.log("Deploying adapter for dex type", _dexType);

        address routerAddress = _router();

        console.log("Router address", routerAddress);

        vm.startBroadcast();

        SkipGoSwapRouter router = SkipGoSwapRouter(payable(routerAddress));

        SkipGoSwapRouter.ExchangeType dexType = _getDexType(_dexType);

        if (dexType == SkipGoSwapRouter.ExchangeType.UNISWAP_V2) {
            UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
            router.addAdapter(dexType, address(uniswapV2Adapter));
        } else if (dexType == SkipGoSwapRouter.ExchangeType.UNISWAP_V3) {
            UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();
            router.addAdapter(dexType, address(uniswapV3Adapter));
        } else if (dexType == SkipGoSwapRouter.ExchangeType.VELODROME) {
            VelodromeAdapter velodromeAdapter = new VelodromeAdapter();
            router.addAdapter(dexType, address(velodromeAdapter));
        }

        vm.stopBroadcast();

        console.log("Adapter deployed at", address(router));
    }

    function _router() internal view returns (address) {
        if (block.chainid == 1) {
            return 0xd1eE705D774d59541d3D395e72A16E48389DF7C7;
        } else if (block.chainid == 42161) {
            return 0xA307099736ff10f6A639D8a00F3C0AC62E10424a;
        } else if (block.chainid == 43114) {
            return 0xfF19fcC8563Aef3a1a83A2F52AeF9AE41D767333;
        } else if (block.chainid == 56) {
            return 0xbC4bdEB1E85C62f5Da9cb732a5209408db7B4769;
        } else if (block.chainid == 8453) {
            return 0xD57611Dd97eacb7AE19aE5d789e943d07f4dfa4f;
        } else if (block.chainid == 81457) {
            return 0x32Fb43172c0afB63770372fDe4A84E9b827Ec903;
        } else if (block.chainid == 42220) {
            return 0xF29F1f9f06054F23B5bC9De9bC5017bff8bF1a05;
        } else if (block.chainid == 10) {
            return 0xc352fB0E5fC310FCbfD736542d45Efa27B9E1Cae;
        } else if (block.chainid == 137) {
            return 0x8A68Dd4b423Ef7568d0cdf3bB8E4863Ca1041a9e;
        }

        revert("Chain not supported");
    }

    function _getDexType(string memory dexType) internal pure returns (SkipGoSwapRouter.ExchangeType) {
        if (keccak256(bytes(dexType)) == keccak256(bytes("UNISWAP_V2"))) {
            return SkipGoSwapRouter.ExchangeType.UNISWAP_V2;
        } else if (keccak256(bytes(dexType)) == keccak256(bytes("UNISWAP_V3"))) {
            return SkipGoSwapRouter.ExchangeType.UNISWAP_V3;
        } else if (keccak256(bytes(dexType)) == keccak256(bytes("VELODROME"))) {
            return SkipGoSwapRouter.ExchangeType.VELODROME;
        }

        revert("Invalid dex type");
    }
}
