pragma solidity ^0.8.20;

import "./BaseScript.sol";

import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CCTPRelayer} from "src/CCTPRelayer.sol";

contract DeploymentScript is BaseScript {
    function run() public {
        vm.startBroadcast();
        // https://snowtrace.io/address/0xdFEB12726CD398e628BA869fbD7Af97c6630A394
        CCTPRelayer relayer = CCTPRelayer(payable(0xdFEB12726CD398e628BA869fbD7Af97c6630A394));
        relayer.setSwapRouter(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);

        vm.stopBroadcast();
    }
}
