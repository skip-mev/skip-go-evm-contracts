// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev Interface for Skip CCTPRelayer contract.
 */
interface ICCTPRelayer {
    error ZeroAddress();
    error TransferFailed();
    error ETHSendFailed();
    error MissingBalance();
    error PaymentCannotBeZero();
    error SwapFailed();
    error InsufficientSwapOutput();
    error InsufficientNativeToken();
    error Reentrancy();

    event PaymentForRelay(uint64 nonce, uint256 paymentAmount, string relayQuoteToken);

    event FailedReceiveMessage(bytes message, bytes attestation);

    struct ReceiveCall {
        bytes message;
        bytes attestation;
    }

    function makePaymentForRelay(uint64 nonce, uint256 paymentAmount, string memory relayQuoteToken) external;

    function requestCCTPTransfer(
        uint256 transferAmount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount,
        uint256 expiryTimestamp,
        string memory relayQuoteToken
    ) external;
}
