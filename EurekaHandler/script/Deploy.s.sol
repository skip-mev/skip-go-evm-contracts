// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EurekaHandler} from "../src/EurekaHandler.sol";

contract DeploymentScript is Script {
    function run() public {
        address lbtc = 0xc47e4b3124597FDF8DD07843D4a7052F2eE80C30;
        address voucher = 0x8f2403F14D0Ca553273b7d55013E499194f9eC78;
        address ics20Transfer = 0xE80DC519EE86146057B9dBEfBa900Edd7a2385e4;
        address swapRouter = 0xd1eE705D774d59541d3D395e72A16E48389DF7C7;
        address owner = 0x24a9267cE9e0a8F4467B584FDDa12baf1Df772B5;

        vm.startBroadcast();

        EurekaHandler handlerImpl = new EurekaHandler();

        ERC1967Proxy handlerProxy = new ERC1967Proxy(
            address(handlerImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address)", owner, ics20Transfer, swapRouter, voucher, lbtc
            )
        );

        EurekaHandler handler = EurekaHandler(payable(address(handlerProxy)));

        vm.stopBroadcast();

        console.log("EurekaHandler deployed at: ", address(handler));
    }
}
