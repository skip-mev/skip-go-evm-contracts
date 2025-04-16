// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {CCTPRelayer} from "src/CCTPRelayer.sol";

contract AxelarHandlerUpgradeScript is Script {
    CCTPRelayer public relayer;

    function setUp() public {
        relayer = CCTPRelayer(payable(0xBC8552339dA68EB65C8b88B414B5854E0E366cFc));
    }

    function run() public {
        vm.startBroadcast();
        CCTPRelayer newImplementation = new CCTPRelayer();
        relayer.upgradeToAndCall(address(newImplementation), bytes(""));
        vm.stopBroadcast();
    }
}
