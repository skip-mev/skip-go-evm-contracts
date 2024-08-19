// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./Environment.sol";
import {MockGateway} from "./mocks/MockGateway.sol";
import {MockRouter} from "./mocks/MockRouter.sol";

import {AxelarHandler} from "src/AxelarHandler.sol";
import {IAxelarExecutable} from "lib/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarExecutable.sol";

import {IAxelarGateway} from "lib/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC20Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ISwapRouter02} from "src/interfaces/ISwapRouter02.sol";

contract AxelarHandlerTest is Test {
    string public constant FORK_CHAIN = "mainnet";

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public immutable ALICE = makeAddr("ALICE");
    address public immutable BOB = makeAddr("BOB");

    bool public isForked;

    AxelarHandler public handler;
    IAxelarGateway public gateway;
    ISwapRouter02 public router;

    modifier forked() {
        isForked = true;
        Environment env = new Environment();
        env.setEnv(1);

        vm.makePersistent(address(env));
        vm.createSelectFork(vm.rpcUrl(FORK_CHAIN));

        gateway = IAxelarGateway(env.gateway());
        address gasService = env.gasService();
        router = ISwapRouter02(env.swapRouter());

        string memory wethSymbol = "WETH";

        AxelarHandler handlerImpl = new AxelarHandler();
        ERC1967Proxy handlerProxy = new ERC1967Proxy(
            address(handlerImpl),
            abi.encodeWithSignature("initialize(address,address,string)", address(gateway), gasService, wethSymbol)
        );
        handler = AxelarHandler(payable(address(handlerProxy)));

        handler.setSwapRouter(address(router));

        vm.label(address(handler), "HANDLER");
        vm.label(address(gateway), "GATEWAY");
        vm.label(gasService, "GAS SERVICE");
        vm.label(gateway.tokenAddresses(wethSymbol), "WETH");

        _;

        isForked = false;
    }

    modifier local() {
        gateway = IAxelarGateway(address(new MockGateway()));
        address gasService = makeAddr("GAS SERVICE");

        router = ISwapRouter02(address(new MockRouter()));

        string memory wethSymbol = "WETH";

        AxelarHandler handlerImpl = new AxelarHandler();
        ERC1967Proxy handlerProxy = new ERC1967Proxy(
            address(handlerImpl),
            abi.encodeWithSignature("initialize(address,address,string)", address(gateway), gasService, wethSymbol)
        );
        handler = AxelarHandler(payable(address(handlerProxy)));

        handler.setSwapRouter(address(router));

        vm.label(address(handler), "HANDLER");
        vm.label(address(gateway), "GATEWAY");
        vm.label(gateway.tokenAddresses(wethSymbol), "WETH");

        _;
    }

    function test_sendNativeToken() public forked {
        vm.deal(ALICE, 10 ether);
        assertEq(ALICE.balance, 10 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        handler.sendNativeToken{value: 10 ether}("arbitrum", vm.toString(BOB));
        vm.stopPrank();

        assertEq(ALICE.balance, 0, "Native balance after sending.");
        assertEq(address(handler).balance, 0, "Ether left in the contract.");
    }

    function test_sendNativeToken_NoAmount() public forked {
        vm.deal(ALICE, 10 ether);
        assertEq(ALICE.balance, 10 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.ZeroNativeSent.selector);
        handler.sendNativeToken{value: 0}("arbitrum", vm.toString(BOB));
        vm.stopPrank();
    }

    function test_sendERC20Token() public forked {
        string memory symbol = "WETH";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), BOB, 100 ether);

        vm.prank(BOB);
        token.approve(address(handler), type(uint256).max);

        vm.prank(BOB);
        handler.sendERC20Token("arbitrum", vm.toString(ALICE), symbol, 20 ether);

        assertEq(token.balanceOf(BOB), 80 ether, "User balance after sending.");
        assertEq(token.balanceOf(address(handler)), 0, "Tokens left in the contract.");
    }

    function test_sendERC20Token_WrongSymbol() public forked {
        string memory symbol = "WBTCx";
        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.TokenNotSupported.selector);
        handler.sendERC20Token("arbitrum", vm.toString(BOB), symbol, 50 ether);
        vm.stopPrank();
    }

    function test_sendERC20Token_NoAllowance() public forked {
        string memory symbol = "WBTC";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether, "Balance before sending.");

        vm.startPrank(ALICE);

        token.approve(address(handler), 49 ether);
        vm.expectRevert();
        handler.sendERC20Token("arbitrum", vm.toString(BOB), symbol, 50 ether);
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken() public forked {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        handler.gmpTransferNativeToken{value: 50.5 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), 50 ether, 0.5 ether
        );
        vm.stopPrank();

        assertEq(ALICE.balance, 49.5 ether, "Native balance after sending.");
        assertEq(address(handler).balance, 0, "Ether left in the contract.");
    }

    function test_gmpTransferNativeToken_ZeroGas() public forked {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.ZeroGasAmount.selector);
        handler.gmpTransferNativeToken{value: 50 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), 50 ether, 0 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken_ZeroAmount() public forked {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.ZeroAmount.selector);
        handler.gmpTransferNativeToken{value: 0.5 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), 0, 0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken_AmountMismatch() public forked {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.NativeSentDoesNotMatchAmounts.selector);
        handler.gmpTransferNativeToken{value: 50 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), 50 ether, 0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferERC20Token() public forked {
        vm.deal(ALICE, 25 ether);
        assertEq(ALICE.balance, 25 ether, "Native balance before sending.");

        string memory symbol = "WBTC";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 5000 ether);
        assertEq(token.balanceOf(ALICE), 5000 ether);

        vm.startPrank(ALICE);
        token.approve(address(handler), 5000 ether);
        handler.gmpTransferERC20Token{value: 25 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), symbol, 4900 ether, 25 ether
        );
        vm.stopPrank();

        assertEq(ALICE.balance, 0, "Native balance after sending.");
        assertEq(token.balanceOf(ALICE), 100 ether, "Token balance after sending.");
        assertEq(address(handler).balance, 0, "Ether left in the contract.");
        assertEq(token.balanceOf(address(handler)), 0, "Tokens left in the contract.");
    }

    function test_gmpTransferERC20Token_GasMismatch() public forked {
        vm.deal(ALICE, 0.5 ether);
        assertEq(ALICE.balance, 0.5 ether, "Native balance before sending.");

        string memory symbol = "WBTC";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether);

        vm.startPrank(ALICE);
        token.approve(address(handler), 100 ether);
        vm.expectRevert(AxelarHandler.NativeSentDoesNotMatchAmounts.selector);
        handler.gmpTransferERC20Token{value: 0.25 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), symbol, 50 ether, 0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferERC20Token_ZeroGas() public forked {
        vm.deal(ALICE, 0.5 ether);
        assertEq(ALICE.balance, 0.5 ether, "Native balance before sending.");

        string memory symbol = "WBTC";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether);

        vm.startPrank(ALICE);
        token.approve(address(handler), 100 ether);
        vm.expectRevert(AxelarHandler.ZeroGasAmount.selector);
        handler.gmpTransferERC20Token(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), symbol, 50 ether, 0
        );
        vm.stopPrank();
    }

    function test_gmpTransferERC20TokenGasTokenPayment() public forked {
        string memory symbol = "WBTC";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(token), "WBTC");

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether);

        vm.startPrank(ALICE);
        token.approve(address(handler), 100 ether);
        handler.gmpTransferERC20TokenGasTokenPayment(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), symbol, 75 ether, 25 ether
        );
        vm.stopPrank();

        assertEq(token.balanceOf(ALICE), 0, "Token balance after sending.");
        assertEq(token.balanceOf(address(handler)), 0, "Tokens left in the contract.");
    }

    function test_executeWithToken_nonunwrap_nonWETH() public forked {
        string memory symbol = "WBTC";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(token), "WBTC");

        deal(address(token), address(this), 100 ether);
        token.transfer(address(handler), 100 ether);

        assertEq(token.balanceOf(address(handler)), 100 ether, "Handler balance before");

        assertEq(token.balanceOf(ALICE), 0, "Alice balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(token));

        bytes memory payload = abi.encode(uint8(0), abi.encode(ALICE));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, 100 ether
        );

        assertEq(token.balanceOf(address(handler)), 0, "Handler balance after");

        assertEq(token.balanceOf(ALICE), 100 ether, "Alice balance after");
    }

    function test_executeWithToken_unwrap_nonWETH() public forked {
        string memory symbol = "WBTC";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(token), "WBTC");

        deal(address(token), address(this), 100 ether);
        token.transfer(address(handler), 100 ether);

        assertEq(token.balanceOf(address(handler)), 100 ether, "Handler balance before");

        assertEq(token.balanceOf(ALICE), 0, "Alice balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(token));

        bytes memory payload = abi.encode(uint8(1), abi.encode(ALICE));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, 100 ether
        );

        assertEq(token.balanceOf(address(handler)), 0, "Handler balance after");

        assertEq(token.balanceOf(ALICE), 100 ether, "Alice balance after");
    }

    function test_executeWithToken_unwrap_WETH() public forked {
        string memory symbol = "WETH";
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(token), "WETH");

        deal(address(token), address(this), 100 ether);
        token.transfer(address(handler), 100 ether);

        assertEq(token.balanceOf(address(handler)), 100 ether, "Handler balance before");

        assertEq(token.balanceOf(ALICE), 0, "Alice token balance before");
        assertEq(ALICE.balance, 0, "Alice native balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(token));

        bytes memory payload = abi.encode(uint8(1), abi.encode(ALICE));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, 100 ether
        );

        assertEq(token.balanceOf(address(handler)), 0, "Handler balance after");
        assertEq(token.balanceOf(ALICE), 0, "Alice token balance after");
        assertEq(ALICE.balance, 100 ether, "Alice native balance after");
    }

    function test_executeWithToken_exactInputSingleSwap_Fork() public forked {
        string memory symbol = "WETH";
        address tokenIn = IAxelarGateway(gateway).tokenAddresses(symbol);
        vm.label(address(tokenIn), symbol);

        address tokenOut = USDC;
        vm.label(address(tokenOut), "USDC");

        uint256 amountIn = 1 ether; // 1 WETH
        uint256 amountOutMin = 1_000 * 1e6; // 1,000 USDC
        address destination = ALICE;
        bool unwrap = false;

        _execute_exactInputSingleSwap(symbol, tokenIn, tokenOut, amountIn, amountOutMin, destination, unwrap);
    }

    function _execute_exactInputSingleSwap(
        string memory symbol,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address destination,
        bool unwrap
    ) internal {
        _mockGateway(symbol, tokenIn, amountIn);

        IERC20 inputToken = IERC20(tokenIn);
        IERC20 outputToken = IERC20(tokenOut);

        assertEq(inputToken.balanceOf(address(handler)), amountIn, "Handler input token balance before");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance before");

        assertEq(inputToken.balanceOf(destination), 0, "Destination input token balance before");
        assertEq(outputToken.balanceOf(destination), 0, "Destination output token balance before");

        bytes memory swapPayload = abi.encode(uint8(0), tokenOut, amountOutMin, abi.encode(uint24(3000), uint160(0)));
        bytes memory payload = abi.encode(uint8(2), abi.encode(destination, unwrap, swapPayload));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, amountIn
        );

        assertEq(inputToken.balanceOf(destination), 0, "Destination input token balance after");
        if (unwrap) {
            assertGt(destination.balance, amountOutMin, "Destination output native balance after");
            assertEq(address(handler).balance, 0, "Handler native token balance after");
        } else {
            assertGt(IERC20(tokenOut).balanceOf(destination), amountOutMin, "Destination output token balance after");
        }
        assertEq(inputToken.balanceOf(address(handler)), 0, "Handler input token balance after");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance after");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router allowance after swap");
    }

    function _mockGateway(string memory symbol, address tokenIn, uint256 amountIn) internal {
        deal(tokenIn, address(handler), amountIn);

        if (isForked) {
            deployCodeTo("MockGateway.sol", address(gateway));
        }

        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, tokenIn);
    }

    function test_executeWithToken_exactInputSwap() public forked {
        uint256 inputAmount = 1 ether;
        uint256 amountOutMinimum = 1000 * 1e6; // 1000 USDC

        string memory symbol = "WETH";
        IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(inputToken), "WETH");

        IERC20Upgradeable outputToken = IERC20Upgradeable(USDC);
        vm.label(address(outputToken), "USDC");

        deal(address(inputToken), address(this), inputAmount);
        inputToken.transfer(address(handler), inputAmount);

        assertEq(inputToken.balanceOf(address(handler)), inputAmount, "Handler input token balance before");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance before");

        assertEq(inputToken.balanceOf(ALICE), 0, "Alice input token balance before");
        assertEq(outputToken.balanceOf(ALICE), 0, "Alice output token balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(inputToken));

        bytes memory path = abi.encodePacked(address(inputToken), uint24(500), address(outputToken));
        bytes memory swapPayload = abi.encode(uint8(1), address(outputToken), amountOutMinimum, path);
        bytes memory payload = abi.encode(uint8(2), abi.encode(ALICE, false, swapPayload));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );

        assertEq(inputToken.balanceOf(ALICE), 0, "Alice input token balance after");
        assertGt(outputToken.balanceOf(ALICE), amountOutMinimum, "Alice output token balance after");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Handler input token balance after");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance after");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router allowance after swap");
    }

    function test_executeWithToken_exactTokensForTokensSwap() public forked {
        uint256 inputAmount = 5 ether;
        uint256 minOutput = 10_000 * 1e6;

        string memory symbol = "WETH";
        IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(inputToken), "WETH");

        IERC20Upgradeable outputToken = IERC20Upgradeable(USDC);
        vm.label(address(inputToken), "USDC");

        deal(address(inputToken), address(this), inputAmount);
        inputToken.transfer(address(handler), inputAmount);

        assertEq(inputToken.balanceOf(address(handler)), inputAmount, "Handler input token balance before");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance before");

        assertEq(inputToken.balanceOf(ALICE), 0, "Alice input token balance before");
        assertEq(outputToken.balanceOf(ALICE), 0, "Alice output token balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(inputToken));

        address[] memory path = new address[](2);
        path[0] = address(inputToken);
        path[1] = address(outputToken);

        bytes memory swapPayload = abi.encode(uint8(2), address(outputToken), minOutput, abi.encode(path));
        bytes memory payload = abi.encode(uint8(2), abi.encode(ALICE, false, swapPayload));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );

        assertEq(inputToken.balanceOf(ALICE), 0, "User got refunded input");
        assertGt(outputToken.balanceOf(ALICE), minOutput, "User balance didn't increase");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Dust leftover in the contract.");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Funds leftover in contract");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router Allowance Remaining After Payment");
    }

    function test_executeWithToken_exactOutputSingleSwap() public forked {
        uint256 inputAmount = 1 ether;
        uint256 amountOut = 1000 * 1e6; // 1000 USDC

        string memory symbol = "WETH";
        IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(inputToken), "WETH");

        IERC20Upgradeable outputToken = IERC20Upgradeable(USDC);
        vm.label(address(outputToken), "USDC");

        deal(address(inputToken), address(this), inputAmount);
        inputToken.transfer(address(handler), inputAmount);

        assertEq(inputToken.balanceOf(address(handler)), inputAmount, "Handler input token balance before");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance before");

        assertEq(inputToken.balanceOf(ALICE), 0, "Alice input token balance before");
        assertEq(outputToken.balanceOf(ALICE), 0, "Alice output token balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(inputToken));

        bytes memory swapPayload =
            abi.encode(uint8(3), address(outputToken), amountOut, abi.encode(uint24(3000), uint160(0)));
        bytes memory payload = abi.encode(uint8(2), abi.encode(ALICE, false, swapPayload));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );

        assertGt(inputToken.balanceOf(ALICE), 0, "Alice input token balance after");
        assertEq(outputToken.balanceOf(ALICE), amountOut, "Alice output token balance after");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Handler input token balance after");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance after");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router allowance after swap");
    }

    function test_executeWithToken_exactOutputSwap() public forked {
        uint256 inputAmount = 1 ether;
        uint256 amountOut = 1000 * 1e6; // 1000 USDC

        string memory symbol = "WETH";
        IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(inputToken), "WETH");

        IERC20Upgradeable outputToken = IERC20Upgradeable(USDC);
        vm.label(address(outputToken), "USDC");

        deal(address(inputToken), address(this), inputAmount);
        inputToken.transfer(address(handler), inputAmount);

        assertEq(inputToken.balanceOf(address(handler)), inputAmount, "Handler input token balance before");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance before");

        assertEq(inputToken.balanceOf(ALICE), 0, "Alice input token balance before");
        assertEq(outputToken.balanceOf(ALICE), 0, "Alice output token balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(inputToken));

        bytes memory path = abi.encodePacked(address(outputToken), uint24(500), address(inputToken));
        bytes memory swapPayload = abi.encode(uint8(4), address(outputToken), amountOut, path);
        bytes memory payload = abi.encode(uint8(2), abi.encode(ALICE, false, swapPayload));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );

        assertGt(inputToken.balanceOf(ALICE), 0, "Alice input token balance after");
        assertEq(outputToken.balanceOf(ALICE), amountOut, "Alice output token balance after");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Handler input token balance after");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance after");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router allowance after swap");
    }

    function test_executeWithToken_tokensForExactTokensSwap() public forked {
        uint256 inputAmount = 5 ether;
        uint256 amountOut = 10_000 * 1e6;

        string memory symbol = "WETH";
        IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
        vm.label(address(inputToken), "WETH");

        IERC20Upgradeable outputToken = IERC20Upgradeable(USDC);
        vm.label(address(inputToken), "USDC");

        deal(address(inputToken), address(this), inputAmount);
        inputToken.transfer(address(handler), inputAmount);

        assertEq(inputToken.balanceOf(address(handler)), inputAmount, "Handler input token balance before");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance before");

        assertEq(inputToken.balanceOf(ALICE), 0, "Alice input token balance before");
        assertEq(outputToken.balanceOf(ALICE), 0, "Alice output token balance before");

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(inputToken));

        address[] memory path = new address[](2);
        path[0] = address(inputToken);
        path[1] = address(outputToken);

        bytes memory swapPayload = abi.encode(uint8(5), address(outputToken), amountOut, abi.encode(path));
        bytes memory payload = abi.encode(uint8(2), abi.encode(ALICE, false, swapPayload));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );

        assertGt(inputToken.balanceOf(ALICE), 0, "User got refunded input");
        assertEq(outputToken.balanceOf(ALICE), amountOut, "User balance didn't increase");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Dust leftover in the contract.");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Funds leftover in contract");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router Allowance Remaining After Payment");
    }

    function test_executeWithToken_custom() public forked {
        uint256 inputAmount = 5 ether;
        string memory symbol = "WETH";
        IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));

        deployCodeTo("MockGateway.sol", address(gateway));
        MockGateway mockGateway = MockGateway(address(gateway));
        mockGateway.saveTokenAddress(symbol, address(inputToken));

        deal(address(inputToken), address(this), inputAmount);
        inputToken.transfer(address(handler), inputAmount);

        bytes memory payload =
            hex"000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000ef211076b8d8b46797e09c9a374fb4cdc1df09160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000004000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000003b9aca000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000";

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );
    }

    // function test_executeWithToken_swap_refundDust() public {
    //     uint256 inputAmount = 4.95 ether;
    //     uint256 dust = 0.05 ether;
    //     uint256 minOutput = 10_000 * 1e6;

    //     string memory symbol = "WETH";
    //     IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses(symbol));
    //     vm.label(address(inputToken), "WETH");

    //     IERC20Upgradeable outputToken = IERC20Upgradeable(USDC);
    //     vm.label(address(inputToken), "USDC");

    //     deal(address(inputToken), address(this), inputAmount);
    //     inputToken.transfer(address(handler), inputAmount);

    //     assertEq(inputToken.balanceOf(address(handler)), inputAmount, "Handler input token balance before");
    //     assertEq(outputToken.balanceOf(address(handler)), 0, "Handler output token balance before");

    //     assertEq(inputToken.balanceOf(ALICE), 0, "Alice input token balance before");
    //     assertEq(outputToken.balanceOf(ALICE), 0, "Alice output token balance before");

    //     deployCodeTo("MockGateway.sol", address(gateway));
    //     MockGateway mockGateway = MockGateway(address(gateway));
    //     mockGateway.saveTokenAddress(symbol, address(inputToken));

    //     address[] memory path = new address[](2);
    //     path[0] = address(inputToken);
    //     path[1] = address(outputToken);
    //     bytes memory swapCalldata =
    //         abi.encodeWithSelector(bytes4(0x472b43f3), inputAmount - dust, minOutput, path, address(handler));
    //     bytes memory payload = abi.encode(uint8(1), abi.encode(ALICE, address(outputToken), swapCalldata));

    //     handler.executeWithToken(
    //         keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
    //     );

    //     assertEq(inputToken.balanceOf(ALICE), dust, "User didn't got dust refunded");
    //     assertGt(outputToken.balanceOf(ALICE), minOutput, "User balance didn't increase");
    //     assertEq(inputToken.balanceOf(address(handler)), 0, "Dust leftover in the contract.");
    //     assertEq(outputToken.balanceOf(address(handler)), 0, "Funds leftover in contract");
    //     assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router Allowance Remaining After Payment");
    // }

    function test_swapAndGmpTransferERC20Token_ETH(
        uint32 domain,
        address inputToken,
        uint256 inputAmount,
        bytes memory swapCalldata
    ) public forked {
        uint256 amount = 2 ether;
        uint256 gasAmount = 0.5 ether;
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses("WBTC"));

        assertEq(ALICE.balance, 0, "Pre-swap user balance");
        assertEq(address(handler).balance, 0, "Pre-swap contract balance");

        vm.deal(ALICE, amount + gasAmount);
        uint256 minAmount = 0.05 * 1e8;
        address[] memory path = new address[](2);
        path[0] = gateway.tokenAddresses("WETH");
        path[1] = address(token);
        bytes memory swapCalldata =
            abi.encodeWithSelector(bytes4(0x472b43f3), amount, minAmount, path, address(handler));

        vm.startPrank(ALICE);
        handler.swapAndGmpTransferERC20Token{value: amount + gasAmount}(
            address(0),
            amount,
            swapCalldata,
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            "WBTC",
            gasAmount
        );
        vm.stopPrank();

        assertEq(ALICE.balance, 0, "User balance increased");
        assertEq(address(handler).balance, 0, "Funds leftover in contract");
        assertEq(token.allowance(address(handler), address(router)), 0, "Router Allowance Remaining After Payment");
        assertEq(token.balanceOf(address(handler)), 0, "Balance Remaining After Payment");
        assertEq(address(handler).balance, 0, "Native balance after sending.");
    }

    function test_swapAndGmpTransferERC20Token_Token(
        uint32 domain,
        address inputToken,
        uint256 inputAmount,
        bytes memory swapCalldata
    ) public forked {
        uint256 amount = 2 ether;
        uint256 gasAmount = 0.5 ether;
        IERC20Upgradeable inputToken = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses("WETH"));
        IERC20Upgradeable token = IERC20Upgradeable(IAxelarGateway(gateway).tokenAddresses("WBTC"));

        assertEq(inputToken.balanceOf(ALICE), 0, "Pre-swap user balance");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Pre-swap contract balance");
        assertEq(address(handler).balance, 0, "Pre-swap contract eth balance");

        vm.deal(ALICE, gasAmount);
        deal(address(inputToken), ALICE, amount);

        uint256 minAmount = 0.05 * 1e8;
        address[] memory path = new address[](2);
        path[0] = address(inputToken);
        path[1] = address(token);
        bytes memory swapCalldata =
            abi.encodeWithSelector(bytes4(0x472b43f3), amount, minAmount, path, address(handler));

        vm.startPrank(ALICE);
        IERC20Upgradeable(path[0]).approve(address(handler), amount);
        handler.swapAndGmpTransferERC20Token{value: gasAmount}(
            path[0],
            amount,
            swapCalldata,
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            "WBTC",
            gasAmount
        );
        vm.stopPrank();

        assertEq(IERC20Upgradeable(path[0]).balanceOf(ALICE), 0, "Handler balance increased");
        assertEq(IERC20Upgradeable(path[1]).balanceOf(ALICE), 0, "Handler balance increased");
        assertEq(address(handler).balance, 0, "Funds leftover in contract");
        assertEq(token.allowance(address(handler), address(router)), 0, "Router Allowance Remaining After Payment");
        assertEq(token.balanceOf(address(handler)), 0, "Balance Remaining After Payment");
        assertEq(address(handler).balance, 0, "Native balance after sending.");
    }
}
