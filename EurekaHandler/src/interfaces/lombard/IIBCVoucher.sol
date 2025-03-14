// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IIBCVoucher {
    /// @notice Gives voucher in exchange for LBTC
    /// @dev LBTC should be approved to `transferFrom`
    /// @param amount Amount of LBTC
    function wrap(uint256 amount) external returns (uint256 voucherAmount);

    /// @notice Spends the voucher and gives LBTC back
    /// @dev No approval required, burns directly from message sender
    /// @param amount Amount of Voucher
    function spend(uint256 amount) external;
}
