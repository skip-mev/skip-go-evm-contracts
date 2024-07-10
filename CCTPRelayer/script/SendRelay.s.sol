pragma solidity ^0.8.20;

import "./BaseScript.sol";

import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CCTPRelayer} from "src/CCTPRelayer.sol";
import {IMessageTransmitter} from "src/interfaces/IMessageTransmitter.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ICCTPRelayer} from "src/interfaces/ICCTPRelayer.sol";

contract DeploymentScript is BaseScript {
    struct ExactInputParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function run() public {
        vm.startBroadcast();

        // this is our production contract deployed on Base. replace with the appropriate address for the chain this is being executed on
        CCTPRelayer relayer = CCTPRelayer(payable(0xBFBf2BC13f2BFa1D4ef3C697D02A7eda021861a8));

        address recipient = 0x56Ca414d41CD3C1188A4939b0D56417dA7Bb6DA2; // this is my address, replace with your own unless you want to give me free money

        uint256 transferAmount = 2_000_000;
        uint32 destinationDomain = 3; // arbtirum
        bytes32 mintRecipient = _addressToBytes32(0xDc2f6bfEBc730B71aA19fccD5990194B40FBCeb6); // deployed arbitrum contract with the new logic
        address burnToken = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E; // USDC, be sure to replace with the appropriate token for the chain this is being executed on
        uint256 feeAmount = 1;
        bytes32 destinationCaller = _addressToBytes32(0xDc2f6bfEBc730B71aA19fccD5990194B40FBCeb6); // deployed arbitrum contract with the new logic

        IERC20(burnToken).approve(address(relayer), transferAmount + feeAmount);

        bytes memory swapCalldata = abi.encodeWithSelector(
            bytes4(0x04e45aaf),
            ExactInputParams({
                tokenIn: address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
                tokenOut: address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
                fee: 3000,
                recipient: recipient,
                amountIn: transferAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        relayer.requestCCTPTransferWithEVMSwap(
            transferAmount,
            destinationDomain,
            mintRecipient,
            burnToken,
            feeAmount,
            destinationCaller,
            recipient,
            swapCalldata
        );

        vm.stopBroadcast();
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
