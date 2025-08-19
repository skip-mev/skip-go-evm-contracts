// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {GoFastHandler} from "../src/GoFastHandler.sol";

contract GoFastHandlerUpgrade is Script {
    function run() external {
        GoFastHandler handler = GoFastHandler(payable(0x2260f6120b634B94A23eF11fa0D615ecf62db3cD));

        vm.startBroadcast();

        GoFastHandler newImplementation = new GoFastHandler();

        handler.upgradeTo(address(newImplementation));

        vm.stopBroadcast();
    }
}
