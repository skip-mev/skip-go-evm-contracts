// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Environment} from "test/Environment.sol";

import {AxelarHandler} from "src/AxelarHandler.sol";

contract AxelarHandlerDeploymentScript is Script {
    Environment public env;
    AxelarHandler public handler;

    function setUp() public {
        env = new Environment();
        env.setEnv(block.chainid);
    }

    function run() public {
        address gateway = env.gateway();
        address gasService = env.gasService();
        string memory wethSymbol = env.wethSymbol();

        vm.startBroadcast();
        handler = new AxelarHandler(gateway, gasService, wethSymbol);
        vm.stopBroadcast();

        console2.log("Axelar Handler Address: ", address(handler));
    }
}
