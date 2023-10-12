// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./Environment.sol";

import {AxelarHandler} from "src/AxelarHandler.sol";

import {IAxelarGateway} from "lib/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AxelarHandlerTest is Test {
    address public immutable ALICE = makeAddr("ALICE");
    address public immutable BOB = makeAddr("BOB");

    AxelarHandler public handler;
    IAxelarGateway public gateway;
    Environment public env;

    function setUp() public {
        env = new Environment();
        env.setEnv(1);

        vm.makePersistent(address(env));

        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/rh1ZDrvuN_YyNFBb_ScfyNapv68fsTKN"
        );

        gateway = IAxelarGateway(env.gateway());
        address gasService = env.gasService();
        string memory wethSymbol = env.wethSymbol();

        handler = new AxelarHandler(address(gateway), gasService, wethSymbol);

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
        string memory symbol = "USDC";
        IERC20 token = IERC20(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(
            token.balanceOf(ALICE),
            100 ether,
            "User balance before sending."
        );

        vm.startPrank(ALICE);

        token.approve(address(handler), 50 ether);
        handler.sendERC20Token("arbitrum", vm.toString(BOB), symbol, 50 ether);
        vm.stopPrank();

        assertEq(
            token.balanceOf(ALICE),
            50 ether,
            "User balance after sending."
        );
        assertEq(
            token.balanceOf(address(handler)),
            0,
            "Tokens left in the contract."
        );
    }

    function test_sendERC20Token_WrongSymbol() public {
        string memory symbol = "USDCx";
        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.TokenNotSupported.selector);
        handler.sendERC20Token("arbitrum", vm.toString(BOB), symbol, 50 ether);
        vm.stopPrank();
    }

    function test_sendERC20Token_NoAllowance() public {
        string memory symbol = "USDC";
        IERC20 token = IERC20(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether, "Balance before sending.");

        vm.startPrank(ALICE);

        token.approve(address(handler), 49 ether);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds allowance"));
        handler.sendERC20Token("arbitrum", vm.toString(BOB), symbol, 50 ether);
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken() public {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        handler.gmpTransferNativeToken{value: 50.5 ether}(
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            50 ether,
            0.5 ether
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
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            50 ether,
            0 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken_ZeroAmount() public {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.ZeroAmount.selector);
        handler.gmpTransferNativeToken{value: 0.5 ether}(
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            0,
            0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferNativeToken_AmountMismatch() public {
        vm.deal(ALICE, 100 ether);
        assertEq(ALICE.balance, 100 ether, "Native balance before sending.");

        vm.startPrank(ALICE);
        vm.expectRevert(AxelarHandler.NativeSentDoesNotMatchAmounts.selector);
        handler.gmpTransferNativeToken{value: 50 ether}(
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            50 ether,
            0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferERC20Token() public {
        vm.deal(ALICE, 0.5 ether);
        assertEq(ALICE.balance, 0.5 ether, "Native balance before sending.");

        string memory symbol = "USDC";
        IERC20 token = IERC20(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether);

        vm.startPrank(ALICE);
        token.approve(address(handler), 100 ether);
        handler.gmpTransferERC20Token{value: 0.5 ether}(
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            symbol,
            50 ether,
            0.5 ether
        );
        vm.stopPrank();

        assertEq(ALICE.balance, 0, "Native balance after sending.");
        assertEq(
            token.balanceOf(ALICE),
            50 ether,
            "Token balance after sending."
        );
        assertEq(address(handler).balance, 0, "Ether left in the contract.");
    }

    function test_gmpTransferERC20Token_GasMismatch() public {
        vm.deal(ALICE, 0.5 ether);
        assertEq(ALICE.balance, 0.5 ether, "Native balance before sending.");

        string memory symbol = "USDC";
        IERC20 token = IERC20(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether);

        vm.startPrank(ALICE);
        token.approve(address(handler), 100 ether);
        vm.expectRevert(AxelarHandler.NativeSentDoesNotMatchAmounts.selector);
        handler.gmpTransferERC20Token{value: 0.25 ether}(
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            symbol,
            50 ether,
            0.5 ether
        );
        vm.stopPrank();
    }

    function test_gmpTransferERC20Token_ZeroGas() public {
        vm.deal(ALICE, 0.5 ether);
        assertEq(ALICE.balance, 0.5 ether, "Native balance before sending.");

        string memory symbol = "USDC";
        IERC20 token = IERC20(IAxelarGateway(gateway).tokenAddresses(symbol));

        deal(address(token), ALICE, 100 ether);
        assertEq(token.balanceOf(ALICE), 100 ether);

        vm.startPrank(ALICE);
        token.approve(address(handler), 100 ether);
        vm.expectRevert(AxelarHandler.ZeroGasAmount.selector);
        handler.gmpTransferERC20Token(
            "arbitrum",
            vm.toString(address(this)),
            abi.encodePacked(address(BOB)),
            symbol,
            50 ether,
            0
        );
        vm.stopPrank();
    }
}
