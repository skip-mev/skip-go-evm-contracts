// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {EurekaHandler, IEurekaHandler} from "../src/EurekaHandler.sol";
import {IICS20Transfer, IICS20TransferMsgs} from "../src/interfaces/eureka/ICS20Transfer.sol";
import {IIBCVoucher} from "../src/interfaces/lombard/IIBCVoucher.sol";

contract EurekaHandlerTest is Test {
    function testTransfer() public {
        address ics20Transfer = 0xbb87C1ACc6306ad2233a4c7BBE75a1230409b358;
        address swapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
        address lbtcVoucher = 0x0000000000000000000000000000000000000000;
        address lbtc = 0x0000000000000000000000000000000000000000;

        EurekaHandler handler = new EurekaHandler(ics20Transfer, swapRouter, lbtcVoucher, lbtc);

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

        IEurekaHandler.Fees memory fees =
            IEurekaHandler.Fees({relayFee: 100, protocolFee: 200, quoteExpiry: uint64(block.timestamp + 100)});

        address alice = makeAddr("alice");

        vm.mockCall(
            token, abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(handler), 300), abi.encode(true)
        );

        vm.mockCall(
            token,
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(handler), amount),
            abi.encode(true)
        );

        vm.mockCall(
            token, abi.encodeWithSelector(IERC20.approve.selector, address(ics20Transfer), amount), abi.encode(true)
        );

        vm.mockCall(
            address(ics20Transfer),
            abi.encodeWithSelector(
                IICS20Transfer.sendTransferWithSender.selector,
                IICS20TransferMsgs.SendTransferMsg({
                    denom: token,
                    amount: amount,
                    receiver: transferParams.recipient,
                    sourceClient: transferParams.sourceClient,
                    destPort: transferParams.destPort,
                    timeoutTimestamp: transferParams.timeoutTimestamp,
                    memo: transferParams.memo
                }),
                alice
            ),
            abi.encode(1)
        );

        vm.startPrank(alice);
        handler.transfer(amount, transferParams, fees);
    }

    function testSwapAndTransfer() public {
        address ics20Transfer = 0xbb87C1ACc6306ad2233a4c7BBE75a1230409b358;
        address swapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
        address lbtcVoucher = 0x0000000000000000000000000000000000000000;
        address lbtc = 0x0000000000000000000000000000000000000000;

        EurekaHandler handler = new EurekaHandler(ics20Transfer, swapRouter, lbtcVoucher, lbtc);

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

        IEurekaHandler.Fees memory fees =
            IEurekaHandler.Fees({relayFee: 100, protocolFee: 200, quoteExpiry: uint64(block.timestamp + 100)});

        address alice = makeAddr("alice");

        vm.mockCall(
            weth,
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(handler), amountIn),
            abi.encode(true)
        );

        {
            bytes[] memory usdcBalanceMockResponses = new bytes[](2);
            usdcBalanceMockResponses[0] = abi.encode(0);
            usdcBalanceMockResponses[1] = abi.encode(100000000);

            vm.mockCalls(
                usdc, abi.encodeWithSelector(IERC20.balanceOf.selector, address(handler)), usdcBalanceMockResponses
            );
        }

        vm.mockCall(weth, abi.encodeWithSelector(IERC20.approve.selector, swapRouter, amountIn), abi.encode(true));

        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.approve.selector, ics20Transfer, 99999700), abi.encode(true));

        vm.mockCall(
            address(ics20Transfer),
            abi.encodeWithSelector(
                IICS20Transfer.sendTransferWithSender.selector,
                IICS20TransferMsgs.SendTransferMsg({
                    denom: usdc,
                    amount: 99999700,
                    receiver: transferParams.recipient,
                    sourceClient: transferParams.sourceClient,
                    destPort: transferParams.destPort,
                    timeoutTimestamp: transferParams.timeoutTimestamp,
                    memo: transferParams.memo
                }),
                alice
            ),
            abi.encode(1)
        );

        vm.startPrank(alice);
        handler.swapAndTransfer(weth, amountIn, swapCalldata, transferParams, fees);
    }

    function testSwapAndTransferRevertsIfInsufficientAmountOut() public {
        address ics20Transfer = 0xbb87C1ACc6306ad2233a4c7BBE75a1230409b358;
        address swapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
        address lbtcVoucher = 0x0000000000000000000000000000000000000000;
        address lbtc = 0x0000000000000000000000000000000000000000;

        EurekaHandler handler = new EurekaHandler(ics20Transfer, swapRouter, lbtcVoucher, lbtc);

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

        IEurekaHandler.Fees memory fees =
            IEurekaHandler.Fees({relayFee: 100, protocolFee: 200, quoteExpiry: uint64(block.timestamp + 100)});

        address alice = makeAddr("alice");

        vm.mockCall(
            weth,
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(handler), amountIn),
            abi.encode(true)
        );

        bytes[] memory usdcBalanceMockResponses = new bytes[](2);
        usdcBalanceMockResponses[0] = abi.encode(0);
        usdcBalanceMockResponses[1] = abi.encode(200);

        vm.mockCalls(
            usdc, abi.encodeWithSelector(IERC20.balanceOf.selector, address(handler)), usdcBalanceMockResponses
        );

        vm.mockCall(weth, abi.encodeWithSelector(IERC20.approve.selector, swapRouter, amountIn), abi.encode(true));

        vm.startPrank(alice);
        vm.expectRevert("Insufficient amount out to cover fees");
        handler.swapAndTransfer(weth, amountIn, swapCalldata, transferParams, fees);
    }

    function testLombardTransfer() public {
        address ics20Transfer = 0xbb87C1ACc6306ad2233a4c7BBE75a1230409b358;
        address swapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
        address lbtcVoucher = makeAddr("lbtcVoucher");
        address lbtc = makeAddr("lbtc");

        EurekaHandler handler = new EurekaHandler(ics20Transfer, swapRouter, lbtcVoucher, lbtc);

        IEurekaHandler.TransferParams memory transferParams = IEurekaHandler.TransferParams({
            token: lbtcVoucher,
            recipient: "cosmos1234",
            sourceClient: "client-0",
            destPort: "transfer",
            timeoutTimestamp: uint64(block.timestamp + 100),
            memo: ""
        });

        IEurekaHandler.Fees memory fees =
            IEurekaHandler.Fees({relayFee: 100, protocolFee: 200, quoteExpiry: uint64(block.timestamp + 100)});

        address alice = makeAddr("alice");

        uint256 amountIn = 100000000;

        vm.mockCall(
            lbtc, abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(handler), 300), abi.encode(true)
        );

        vm.mockCall(
            lbtc,
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(handler), amountIn),
            abi.encode(true)
        );

        vm.mockCall(
            lbtc, abi.encodeWithSelector(IERC20.approve.selector, address(lbtcVoucher), amountIn), abi.encode(true)
        );

        vm.mockCall(lbtcVoucher, abi.encodeWithSelector(IIBCVoucher.get.selector, amountIn), abi.encode(99000000));

        vm.mockCall(
            lbtcVoucher,
            abi.encodeWithSelector(IERC20.approve.selector, address(ics20Transfer), 99000000),
            abi.encode(true)
        );

        vm.mockCall(
            address(ics20Transfer),
            abi.encodeWithSelector(
                IICS20Transfer.sendTransferWithSender.selector,
                IICS20TransferMsgs.SendTransferMsg({
                    denom: lbtcVoucher,
                    amount: 99000000,
                    receiver: transferParams.recipient,
                    sourceClient: transferParams.sourceClient,
                    destPort: transferParams.destPort,
                    timeoutTimestamp: transferParams.timeoutTimestamp,
                    memo: transferParams.memo
                }),
                alice
            ),
            abi.encode(1)
        );

        vm.startPrank(alice);
        handler.lombardTransfer(amountIn, transferParams, fees);
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
