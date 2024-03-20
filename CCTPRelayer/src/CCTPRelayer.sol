pragma solidity ^0.8.20;

import {Initializable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

import {ICCTPRelayer} from "./interfaces/ICCTPRelayer.sol";
import {ITokenMessenger} from "./interfaces/ITokenMessenger.sol";
import {IMessageTransmitter} from "./interfaces/IMessageTransmitter.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract CCTPRelayer is ICCTPRelayer, Initializable, UUPSUpgradeable, Ownable2StepUpgradeable {
    IERC20 public usdc;
    ITokenMessenger public messenger;
    IMessageTransmitter public transmitter;

    constructor() {
        _disableInitializers();
    }

    function initialize(address usdc_, address messenger_, address transmitter_) external initializer {
        __Ownable2Step_init();

        if (usdc_ == address(0)) revert ZeroAddress();
        if (messenger_ == address(0)) revert ZeroAddress();
        if (transmitter_ == address(0)) revert ZeroAddress();

        usdc = IERC20(usdc_);
        messenger = ITokenMessenger(messenger_);
        transmitter = IMessageTransmitter(transmitter_);

        _transferOwnership(msg.sender);
    }

    function makePaymentForRelay(uint64 nonce, uint256 paymentAmount) external {
        if (paymentAmount == 0) revert PaymentCannotBeZero();
        // Transfer the funds from the user into the contract and fail if the transfer reverts.
        if (!usdc.transferFrom(msg.sender, address(this), paymentAmount)) revert TransferFailed();

        // If the transfer succeeds, emit the payment event.
        emit PaymentForRelay(nonce, paymentAmount);
    }

    function requestCCTPTransfer(
        uint256 transferAmount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount
    ) external {
        if (transferAmount == 0) revert PaymentCannotBeZero();
        if (feeAmount == 0) revert PaymentCannotBeZero();
        // In order to save gas do the transfer only once, of both transfer amount and fee amount.
        if (!usdc.transferFrom(msg.sender, address(this), transferAmount + feeAmount)) revert TransferFailed();

        // Only give allowance of the transfer amount, as we want the fee amount to stay in the contract.
        usdc.approve(address(messenger), transferAmount);

        // Call deposit for burn and save the nonce.
        uint64 nonce = messenger.depositForBurn(transferAmount, destinationDomain, mintRecipient, burnToken);

        // As user already paid for the fee we emit the payment event.
        emit PaymentForRelay(nonce, feeAmount);
    }

    function requestCCTPTransferWithCaller(
        uint256 transferAmount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount,
        bytes32 destinationCaller
    ) external {
        if (transferAmount == 0) revert PaymentCannotBeZero();
        if (feeAmount == 0) revert PaymentCannotBeZero();
        // In order to save gas do the transfer only once, of both transfer amount and fee amount.
        if (!usdc.transferFrom(msg.sender, address(this), transferAmount + feeAmount)) revert TransferFailed();

        // Only give allowance of the transfer amount, as we want the fee amount to stay in the contract.
        usdc.approve(address(messenger), transferAmount);

        // Call deposit for burn and save the nonce.
        uint64 nonce = messenger.depositForBurnWithCaller(
            transferAmount, destinationDomain, mintRecipient, burnToken, destinationCaller
        );

        // As user already paid for the fee we emit the payment event.
        emit PaymentForRelay(nonce, feeAmount);
    }

    function batchReceiveMessage(ICCTPRelayer.ReceiveCall[] memory receiveCalls) external {
        // Save gas by not retrieving the length on each loop.
        uint256 length = receiveCalls.length;

        for (uint256 i; i < length;) {
            // Save the message and the attestation.
            bytes memory message = receiveCalls[i].message;
            bytes memory attestation = receiveCalls[i].attestation;

            // Call the transmitter, if fails, emit the event, otherwise skip to the next pair in the array.
            if (!transmitter.receiveMessage(message, attestation)) {
                emit FailedReceiveMessage(message, attestation);
            }

            unchecked {
                ++i;
            }
        }
    }

    function withdraw(address receiver, uint256 amount) external onlyOwner {
        // Check that the contract has enough balance.
        if (usdc.balanceOf(address(this)) < amount) revert MissingBalance();

        // Check that the transfer succeeds.
        if (!usdc.transfer(receiver, amount)) revert TransferFailed();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
