// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {EurekaHandler, IEurekaHandler} from "../src/EurekaHandler.sol";

contract EurekaHandlerTest is Test {
    uint256 sepoliaFork;

    function setUp() public {
        vm.selectFork(sepoliaFork);
        vm.rollFork(7824754);
    }

    function testTransfer() public {
        EurekaHandler handler = new EurekaHandler(
            0xbb87C1ACc6306ad2233a4c7BBE75a1230409b358,
            0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E,
            address(0),
            address(0)
        );

        address token = 0xC30eDcAd074F093882D80424962415Cf61494258;
        uint256 amount = 1_000_000;

        IEurekaHandler.TransferParams memory transferParams = IEurekaHandler.TransferParams({
            token: token,
            recipient: "cosmos1234",
            sourceClient: "client-0",
            destPort: "transfer",
            timeoutTimestamp: uint64(block.timestamp + 100),
            memo: ""
        });

        IEurekaHandler.Fees memory fees = IEurekaHandler.Fees({relayFee: 100, protocolFee: 200});

        address alice = makeAddr("alice");
        deal(token, alice, 100000000);

        vm.startPrank(alice);
        IERC20(token).approve(address(handler), amount + fees.relayFee + fees.protocolFee);

        handler.transfer(amount, transferParams, fees);
    }

    function testSwapAndTransfer() public {
        EurekaHandler handler = new EurekaHandler(
            0xbb87C1ACc6306ad2233a4c7BBE75a1230409b358,
            0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E,
            address(0),
            address(0)
        );

        address weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

        uint256 amountIn = 0.05 ether;

        bytes memory swapCalldata = _encodeSwapExactInputCalldata(weth, usdc, 500, address(handler), amountIn, 0, 0);

        IEurekaHandler.TransferParams memory transferParams = IEurekaHandler.TransferParams({
            token: usdc,
            recipient: "cosmos1234",
            sourceClient: "client-0",
            destPort: "transfer",
            timeoutTimestamp: uint64(block.timestamp + 100),
            memo: ""
        });

        IEurekaHandler.Fees memory fees = IEurekaHandler.Fees({relayFee: 100, protocolFee: 200});

        address alice = makeAddr("alice");
        deal(weth, alice, amountIn);

        vm.startPrank(alice);
        IERC20(weth).approve(address(handler), amountIn);

        handler.swapAndTransfer(weth, amountIn, swapCalldata, transferParams, fees);
    }

    function testSwapAndTransferRevertsIfInsufficientAmountOut() public {
        EurekaHandler handler = new EurekaHandler(
            0xbb87C1ACc6306ad2233a4c7BBE75a1230409b358,
            0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E,
            address(0),
            address(0)
        );

        address weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

        uint256 amountIn = 1000000000;

        bytes memory swapCalldata = _encodeSwapExactInputCalldata(weth, usdc, 500, address(handler), amountIn, 0, 0);

        IEurekaHandler.TransferParams memory transferParams = IEurekaHandler.TransferParams({
            token: usdc,
            recipient: "cosmos1234",
            sourceClient: "client-0",
            destPort: "transfer",
            timeoutTimestamp: uint64(block.timestamp + 100),
            memo: ""
        });

        IEurekaHandler.Fees memory fees = IEurekaHandler.Fees({relayFee: 100, protocolFee: 200});

        address alice = makeAddr("alice");
        deal(weth, alice, amountIn);

        vm.startPrank(alice);
        IERC20(weth).approve(address(handler), amountIn);

        vm.expectRevert("Insufficient amount out to cover fees");
        handler.swapAndTransfer(weth, amountIn, swapCalldata, transferParams, fees);
    }

    function _encodeSwapExactInputCalldata(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            bytes4(0x04e45aaf), tokenIn, tokenOut, fee, recipient, amountIn, amountOutMinimum, sqrtPriceLimitX96
        );
    }
}
