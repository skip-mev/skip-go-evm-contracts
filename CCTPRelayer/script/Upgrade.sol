// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {CCTPRelayer} from "src/CCTPRelayer.sol";

contract AxelarHandlerUpgradeScript is Script {
    CCTPRelayer public relayer;

    function setUp() public {
        relayer = CCTPRelayer(payable(0x32cb9574650AFF312c80edc4B4343Ff5500767cA));
    }

    function run() public {
        vm.startBroadcast();
        CCTPRelayer newImplementation = new CCTPRelayer();
        relayer.upgradeToAndCall(address(newImplementation), bytes(""));
        vm.stopBroadcast();
    }
}
