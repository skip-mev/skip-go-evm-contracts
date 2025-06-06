pragma solidity ^0.8.20;

import "./BaseScript.sol";

import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CCTPRelayer} from "../src/CCTPRelayer.sol";

contract SetRouterScript is BaseScript {
    function run() public {
        vm.startBroadcast();

        CCTPRelayer relayer = CCTPRelayer(payable(0x5E4e84D73850D6aD3bd2f8D1f4dc0C1A8FD3743e));
        relayer.setSwapRouter(0xE9049014d57a114afeD1AC3Df10168e32b0b2077);

        vm.stopBroadcast();
    }
}
