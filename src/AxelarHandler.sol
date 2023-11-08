// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IWETH} from "./interfaces/IWETH.sol";

import {IAxelarGasService} from "lib/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutableUpgradeable} from "./AxelarExecutableUpgradeable.sol";

import {IERC20Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {Ownable2StepUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title AxelarHandler
/// @notice allows to send and receive tokens to/from other chains through axelar gateway while wrapping the native tokens.
/// @author Skip Protocol.
contract AxelarHandler is
    AxelarExecutableUpgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    error EmptySymbol();
    error NativeSentDoesNotMatchAmounts();
    error TokenNotSupported();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroGasAmount();
    error ZeroNativeSent();
    error NonNativeCannotBeUnwrapped();
    error NativePaymentFailed();

    bytes32 private immutable _wETHSymbolHash;

    string public wETHSymbol;
    IAxelarGasService public gasService;

    mapping(address => bool) public approved;

    constructor(
        address axGateway,
        address axGasService,
        string memory wethSymbol
    ) AxelarExecutableUpgradeable(axGateway) {
        if (axGasService == address(0)) revert ZeroAddress();
        if (bytes(wethSymbol).length == 0) revert EmptySymbol();

        gasService = IAxelarGasService(axGasService);
        wETHSymbol = wethSymbol;
        _wETHSymbolHash = keccak256(abi.encodePacked(wethSymbol));
    }

    /// @notice Sends native currency to other chains through the axelar gateway.
    /// @param destinationChain name of the destination chain.
    /// @param destinationAddress address of the destination wallet in string form.
    function sendNativeToken(
        string memory destinationChain,
        string memory destinationAddress
    ) external payable {
        if (msg.value == 0) revert ZeroNativeSent();

        // Get the token address from the gateway.
        address token = _getTokenAddress(wETHSymbol);

        // Wrap the sent ether.
        IWETH(token).deposit{value: msg.value}();

        // Call Axelar Gateway to transfer the WETH.
        gateway.sendToken(
            destinationChain,
            destinationAddress,
            wETHSymbol,
            msg.value
        );
    }

    /// @notice Sends a ERC20 token to other chains through the axelar gateway.
    /// @param destinationChain name of the destination chain.
    /// @param destinationAddress address of the destination wallet in string form.
    /// @param symbol the symbol of the ERC20 token to be sent.
    /// @param amount amount of tokens to be sent.
    function sendERC20Token(
        string memory destinationChain,
        string memory destinationAddress,
        string memory symbol,
        uint256 amount
    ) external {
        if (amount == 0) revert ZeroAmount();
        if (bytes(symbol).length == 0) revert EmptySymbol();

        IERC20Upgradeable token = IERC20Upgradeable(_getTokenAddress(symbol));

        token.safeTransferFrom(msg.sender, address(this), amount);

        gateway.sendToken(destinationChain, destinationAddress, symbol, amount);
    }

    /// @notice Sends native tokens to other chain while calling a contract in the destination chain.
    /// @param destinationChain name of the destination chain.
    /// @param contractAddress address of the contract that will be called in the destination chain.
    /// @param payload the payload that will be sent to the contract in the destination chain.
    /// @param amount amount of tokens to be sent.
    /// @param gasPaymentAmount the amount of native currency that will be used for paying gas.
    /// @dev The amount of native currency sent (msg.value) must be equal to amount + gasPaymentAmount.
    function gmpTransferNativeToken(
        string memory destinationChain, // argument passed to both child contract calls
        string memory contractAddress, // argument passed to both child contract calls
        bytes memory payload, // argument passed to both child contract calls
        uint256 amount, // argument passed to both child contract calls
        uint256 gasPaymentAmount
    ) external payable {
        if (amount == 0) revert ZeroAmount();
        if (gasPaymentAmount == 0) revert ZeroGasAmount();
        if (msg.value != amount + gasPaymentAmount)
            revert NativeSentDoesNotMatchAmounts();

        // Wrap the ether to be sent into the gateway.
        IWETH(_getTokenAddress(wETHSymbol)).deposit{value: amount}();

        gasService.payNativeGasForContractCallWithToken{
            value: gasPaymentAmount
        }(
            address(this),
            destinationChain,
            contractAddress,
            payload,
            wETHSymbol,
            amount,
            msg.sender
        );

        gateway.callContractWithToken(
            destinationChain,
            contractAddress,
            payload,
            wETHSymbol,
            amount
        );
    }

    /// @notice Sends ERC20 to other chain while calling a contract in the destination chain and paying gas with native token.
    /// @param destinationChain name of the destination chain.
    /// @param contractAddress address of the contract that will be called in the destination chain.
    /// @param payload the payload that will be sent to the contract in the destination chain.
    /// @param symbol the symbol of the ERC20 token to be sent.
    /// @param amount amount of tokens to be sent.
    /// @param gasPaymentAmount the amount of native currency that will be used for paying gas.
    /// @dev The amount of native currency sent (msg.value) must be equal to gasPaymentAmount.
    function gmpTransferERC20Token(
        string memory destinationChain, // argument passed to both child contract calls
        string memory contractAddress, // argument passed to both child contract calls
        bytes memory payload, // argument passed to both child contract calls
        string memory symbol, // argument passed to both child contract calls
        uint256 amount, // argument passed to both child contract calls
        uint256 gasPaymentAmount // amount to send with gas payment call
    ) external payable {
        if (amount == 0) revert ZeroAmount();
        if (gasPaymentAmount == 0) revert ZeroGasAmount();
        if (msg.value != gasPaymentAmount)
            revert NativeSentDoesNotMatchAmounts();
        if (bytes(symbol).length == 0) revert EmptySymbol();

        // Get the token address.
        IERC20Upgradeable token = IERC20Upgradeable(_getTokenAddress(symbol));

        // Transfer the amount from the msg.sender.
        token.safeTransferFrom(msg.sender, address(this), amount);

        gasService.payNativeGasForContractCallWithToken{
            value: gasPaymentAmount
        }(
            address(this),
            destinationChain,
            contractAddress,
            payload,
            symbol,
            amount,
            msg.sender
        );

        require(token.balanceOf(address(this)) >= amount, "NOT ENOUGH BALANCE");

        gateway.callContractWithToken(
            destinationChain,
            contractAddress,
            payload,
            symbol,
            amount
        );
    }

    /// @notice Sends ERC20 to other chain while calling a contract in the destination chain and paying gas with destination token.
    /// @param destinationChain name of the destination chain.
    /// @param contractAddress address of the contract that will be called in the destination chain.
    /// @param payload the payload that will be sent to the contract in the destination chain.
    /// @param symbol the symbol of the ERC20 token to be sent.
    /// @param amount amount of tokens to be sent.
    /// @param gasPaymentAmount the amount of native currency that will be used for paying gas.
    /// @dev The amount of native currency sent (msg.value) must be equal to gasPaymentAmount.
    function gmpTransferERC20TokenGasTokenPayment(
        string memory destinationChain, // argument passed to both child contract calls
        string memory contractAddress, // argument passed to both child contract calls
        bytes memory payload, // argument passed to both child contract calls
        string memory symbol, // argument passed to both child contract calls
        uint256 amount, // argument passed to both child contract calls
        uint256 gasPaymentAmount // amount to send with gas payment call
    ) external {
        if (amount == 0) revert ZeroAmount();
        if (gasPaymentAmount == 0) revert ZeroGasAmount();
        if (bytes(symbol).length == 0) revert EmptySymbol();

        // Get the token address.
        IERC20Upgradeable token = IERC20Upgradeable(_getTokenAddress(symbol));

        // Transfer the amount and gas payment amount from the msg.sender.
        token.safeTransferFrom(
            msg.sender,
            address(this),
            amount + gasPaymentAmount
        );

        gasService.payGasForContractCallWithToken(
            address(this),
            destinationChain,
            contractAddress,
            payload,
            symbol,
            amount,
            address(token),
            gasPaymentAmount,
            msg.sender
        );

        gateway.callContractWithToken(
            destinationChain,
            contractAddress,
            payload,
            symbol,
            amount
        );
    }

    /// @notice Ensures a token is supported by the axelar gateway, and returns it's address.
    /// @param symbol the symbol of the ERC20 token to be checked.
    function _getTokenAddress(
        string memory symbol
    ) internal returns (address token) {
        token = gateway.tokenAddresses(symbol);
        if (token == address(0)) revert TokenNotSupported();

        if (!approved[token]) {
            IERC20Upgradeable(token).approve(
                address(gateway),
                type(uint256).max
            );
            IERC20Upgradeable(token).approve(
                address(gasService),
                type(uint256).max
            );
            approved[token] = true;
        }
    }

    /// @notice Internal function called by the AxelarExecutor when a GMP call is made to this contract.
    /// @notice Receives the tokens and unwraps them if it's wrapped native currency.
    /// @param sourceChain the name of the chain where the GMP message originated.
    /// @param sourceAddress the address where the GMP message originated.
    /// @param sourceChain the payload that was sent along with the GMP message.
    /// @param tokenSymbol the symbol of the tokens received.
    /// @param amount the amount of tokens received.
    function _executeWithToken(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        (bool unwrap, address destination) = abi.decode(
            payload,
            (bool, address)
        );
        IERC20Upgradeable token = IERC20Upgradeable(
            _getTokenAddress(tokenSymbol)
        );

        // If unwrap is set and the token can be unwrapped.
        if (
            unwrap &&
            keccak256(abi.encodePacked(tokenSymbol)) != _wETHSymbolHash
        ) {
            // Unwrap native token.
            IWETH weth = IWETH(address(token));
            weth.withdraw(amount);

            // Send it unwrapped to the destination
            (bool success, ) = destination.call{value: amount}("");

            if (!success) {
                revert NativePaymentFailed();
            }
        }
        // Just send the tokens received to the destination.
        else {
            token.safeTransfer(destination, amount);
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
