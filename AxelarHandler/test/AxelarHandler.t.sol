// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./Environment.sol";
import "./mocks/MockGateway.sol";

import {AxelarHandler} from "src/AxelarHandler.sol";
import {IAxelarExecutable} from "lib/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarExecutable.sol";

import {IAxelarGateway} from "lib/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";

import {IERC20Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AxelarHandlerTest is Test {
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public immutable ALICE = makeAddr("ALICE");
    address public immutable BOB = makeAddr("BOB");

    AxelarHandler public handler;
    IAxelarGateway public gateway;
    Environment public env;
    address public router;

    function setUp() public {
        env = new Environment();
        env.setEnv(1);

        vm.makePersistent(address(env));

        vm.createSelectFork("https://eth.llamarpc.com");

        gateway = IAxelarGateway(0x4F4495243837681061C4743b74B3eEdf548D56A5);
        address gasService = 0x2d5d7d31F671F86C782533cc367F14109a082712;
        router = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        string memory wethSymbol = "WETH";

        AxelarHandler handlerImpl = new AxelarHandler();
        ERC1967Proxy handlerProxy = new ERC1967Proxy(
            address(handlerImpl),
            abi.encodeWithSignature("initialize(address,address,string)", address(gateway), gasService, wethSymbol)
        );
        handler = AxelarHandler(payable(address(handlerProxy)));

        handler.setSwapRouter(router);

        vm.label(address(handler), "HANDLER");
        vm.label(address(gateway), "GATEWAY");
        vm.label(gasService, "GAS SERVICE");
        vm.label(gateway.tokenAddresses(wethSymbol), "WETH");
    }

    function test_sendNativeToken() public {
        vm.deal(ALICE, 10 ether);
        assertEq(ALICE.balance, 10 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        handler.sendNativeToken{value: 10 ether}("arbitrum", vm.toString(BOB));
        vm.stopPrank();

        assertEq(ALICE.balance, 0, "Native balance after sending.");
        assertEq(address(handler).balance, 0, "Ether left in the contract.");
    }

    function test_sendNativeToken_NoAmount() public {
        vm.deal(ALICE, 10 ether);
        assertEq(ALICE.balance, 10 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.ZeroNativeSent.selector);
        handler.sendNativeToken{value: 0}("arbitrum", vm.toString(BOB));
        vm.stopPrank();
    }

    function test_sendERC20Token() public {
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

    function test_sendERC20Token_WrongSymbol() public {
        string memory symbol = "WBTCx";
        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.TokenNotSupported.selector);
        handler.sendERC20Token("arbitrum", vm.toString(BOB), symbol, 50 ether);
        vm.stopPrank();
    }

    function test_sendERC20Token_NoAllowance() public {
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

    function test_gmpTransferNativeToken() public {
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

    function test_gmpTransferNativeToken_ZeroGas() public {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.ZeroGasAmount.selector);
        handler.gmpTransferNativeToken{value: 50 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), 50 ether, 0 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken_ZeroAmount() public {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.ZeroAmount.selector);
        handler.gmpTransferNativeToken{value: 0.5 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), 0, 0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken_AmountMismatch() public {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.NativeSentDoesNotMatchAmounts.selector);
        handler.gmpTransferNativeToken{value: 50 ether}(
            "arbitrum", vm.toString(address(this)), abi.encodePacked(address(BOB)), 50 ether, 0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferERC20Token() public {
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

    function test_gmpTransferERC20Token_GasMismatch() public {
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

    function test_gmpTransferERC20Token_ZeroGas() public {
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

    function test_gmpTransferERC20TokenGasTokenPayment() public {
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

    function test_executeWithToken_nonunwrap_nonWETH() public {
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

        bytes memory payload = abi.encode(uint8(0), abi.encode(true, ALICE));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, 100 ether
        );

        assertEq(token.balanceOf(address(handler)), 0, "Handler balance after");

        assertEq(token.balanceOf(ALICE), 100 ether, "Alice balance after");
    }

    function test_executeWithToken_unwrap_nonWETH() public {
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

        bytes memory payload = abi.encode(uint8(0), abi.encode(false, ALICE));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, 100 ether
        );

        assertEq(token.balanceOf(address(handler)), 0, "Handler balance after");

        assertEq(token.balanceOf(ALICE), 100 ether, "Alice balance after");
    }

    function test_executeWithToken_unwrap_WETH() public {
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

        bytes memory payload = abi.encode(uint8(0), abi.encode(true, ALICE));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, 100 ether
        );

        assertEq(token.balanceOf(address(handler)), 0, "Handler balance after");
        assertEq(token.balanceOf(ALICE), 0, "Alice token balance after");
        assertEq(ALICE.balance, 100 ether, "Alice native balance after");
    }

    function test_executeWithToken_swap() public {
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
        bytes memory swapCalldata =
            abi.encodeWithSelector(bytes4(0x472b43f3), inputAmount, minOutput, path, address(handler));
        bytes memory payload = abi.encode(uint8(1), abi.encode(ALICE, address(outputToken), swapCalldata));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );

        assertEq(inputToken.balanceOf(ALICE), 0, "User got refunded input");
        assertGt(outputToken.balanceOf(ALICE), minOutput, "User balance didn't increase");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Dust leftover in the contract.");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Funds leftover in contract");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router Allowance Remaining After Payment");
    }

    function test_executeWithToken_swap_refundDust() public {
        uint256 inputAmount = 4.95 ether;
        uint256 dust = 0.05 ether;
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
        bytes memory swapCalldata =
            abi.encodeWithSelector(bytes4(0x472b43f3), inputAmount - dust, minOutput, path, address(handler));
        bytes memory payload = abi.encode(uint8(1), abi.encode(ALICE, address(outputToken), swapCalldata));

        handler.executeWithToken(
            keccak256(abi.encodePacked("COMMAND_ID")), "osmosis-7", "mock_address", payload, symbol, inputAmount
        );

        assertEq(inputToken.balanceOf(ALICE), dust, "User didn't got dust refunded");
        assertGt(outputToken.balanceOf(ALICE), minOutput, "User balance didn't increase");
        assertEq(inputToken.balanceOf(address(handler)), 0, "Dust leftover in the contract.");
        assertEq(outputToken.balanceOf(address(handler)), 0, "Funds leftover in contract");
        assertEq(inputToken.allowance(address(handler), address(router)), 0, "Router Allowance Remaining After Payment");
    }

    function test_swapAndGmpTransferERC20Token_ETH(
        uint32 domain,
        address inputToken,
        uint256 inputAmount,
        bytes memory swapCalldata
    ) public {
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
    ) public {
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
