// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IEurekaHandler {
    struct TransferParams {
        address token;
        string recipient;
        string sourceClient;
        string destPort;
        uint64 timeoutTimestamp;
        string memo;
    }

    struct Fees {
        uint256 relayFee;
        address relayFeeRecipient;
        uint64 quoteExpiry;
    }

    function transfer(uint256 amount, TransferParams memory transferParams, Fees memory fees) external payable;

    function swapAndTransfer(
        address swapInputToken,
        uint256 swapInputAmount,
        bytes memory swapCalldata,
        TransferParams memory transferParams,
        Fees memory fees
    ) external payable;

    function lombardTransfer(
        uint256 amount,
        uint256 minAmountOut,
        TransferParams memory transferParams,
        Fees memory fees
    ) external;
}
