// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {AxelarHandler} from "../src/AxelarHandler.sol";

contract AxelarHandlerSetRouterScript is Script {
    AxelarHandler public handler;
    address public router;

    function setUp() public {
        handler = AxelarHandler(payable(0x176521bc70B0b575B5d76F6C2456dC2C70D5178C));
        router = 0xE9049014d57a114afeD1AC3Df10168e32b0b2077;
    }

    function run() public {
        vm.startBroadcast();
        handler.setSwapRouter(router);
        vm.stopBroadcast();
    }
}
