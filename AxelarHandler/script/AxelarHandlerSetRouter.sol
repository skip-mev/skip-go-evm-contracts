// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {AxelarHandler} from "../src/AxelarHandler.sol";

contract AxelarHandlerSetRouterScript is Script {
    AxelarHandler public handler;
    address public router;

    function setUp() public {
        handler = AxelarHandler(payable(0x73529dcA22c23B41325cC50d440D61663c15dD94));
        router = 0x32Fb43172c0afB63770372fDe4A84E9b827Ec903;
    }

    function run() public {
        vm.startBroadcast();
        handler.setSwapRouter(router);
        vm.stopBroadcast();
    }
}
