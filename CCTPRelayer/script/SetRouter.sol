pragma solidity ^0.8.20;

import "./BaseScript.sol";

import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CCTPRelayer} from "../src/CCTPRelayer.sol";

contract SetRouterScript is BaseScript {
    function run() public {
        vm.startBroadcast();

        CCTPRelayer relayer = CCTPRelayer(payable(0x1fe8e504D2Fbd2dfdEB271C6B92016bF0454177f));
        relayer.setSwapRouter(0x8A68Dd4b423Ef7568d0cdf3bB8E4863Ca1041a9e);

        vm.stopBroadcast();
    }
}
