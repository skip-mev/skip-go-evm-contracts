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
    address public swapRouter;
    bool internal reentrant;

    modifier nonReentrant() {
        if (reentrant) revert Reentrancy();
        reentrant = true;
        _;
        reentrant = false;
    }

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

    function setSwapRouter(address _swapRouter) external onlyOwner {
        if (_swapRouter == address(0)) revert ZeroAddress();

        swapRouter = _swapRouter;
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

    function swapAndRequestCCTPTransfer(
        address inputToken,
        uint256 inputAmount,
        bytes memory swapCalldata,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount
    ) external payable nonReentrant {
        if (inputAmount == 0) revert PaymentCannotBeZero();
        if (feeAmount == 0) revert PaymentCannotBeZero();

        uint256 outputAmount;
        if (inputToken == address(0)) {
            IERC20 token = IERC20(inputToken);

            // Native Token
            if (inputAmount != msg.value) revert InsufficientNativeToken();

            // Get the contract's balances previous to the swap
            uint256 preInputBalance = address(this).balance - inputAmount;
            uint256 preOutputBalance = usdc.balanceOf(address(this));

            // Call the swap router and perform the swap
            (bool success,) = swapRouter.call{value: inputAmount}(swapCalldata);
            if (!success) revert SwapFailed();

            // Get the contract's balances after the swap
            uint256 postInputBalance = address(this).balance;
            uint256 postOutputBalance = usdc.balanceOf(address(this));

            // Check that the contract's native token balance has increased
            if (preOutputBalance >= postOutputBalance) revert InsufficientSwapOutput();
            outputAmount = postOutputBalance - preOutputBalance;

            // Refund the remaining ETH
            uint256 dust = postInputBalance - preInputBalance;
            if (dust != 0) {
                (bool ethSuccess,) = msg.sender.call{value: dust}("");
                if (!ethSuccess) revert ETHSendFailed();
            }
        } else {
            IERC20 token = IERC20(inputToken);

            // Get the contract's balances previous to the swap
            uint256 preInputBalance = token.balanceOf(address(this));
            uint256 preOutputBalance = usdc.balanceOf(address(this));

            // Transfer input ERC20 tokens to the contract
            token.transferFrom(msg.sender, address(this), inputAmount);

            // Approve the swap router to spend the input tokens
            token.approve(swapRouter, inputAmount);

            // Call the swap router and perform the swap
            (bool success,) = swapRouter.call(swapCalldata);
            if (!success) revert SwapFailed();

            // Get the contract's balances after the swap
            uint256 postInputBalance = token.balanceOf(address(this));
            uint256 postOutputBalance = usdc.balanceOf(address(this));

            // Check that the contract's output token balance has increased
            if (preOutputBalance >= postOutputBalance) revert InsufficientSwapOutput();
            outputAmount = postOutputBalance - preOutputBalance;

            // Refund the remaining amount
            uint256 dust = postInputBalance - preInputBalance;
            if (dust != 0) {
                token.transfer(msg.sender, dust);

                // Revoke Approval
                token.approve(swapRouter, 0);
            }
        }

        // Check that output amount is enough to cover the fee
        if (outputAmount <= feeAmount) revert InsufficientSwapOutput();
        uint256 transferAmount = outputAmount - feeAmount;

        // Only give allowance of the transfer amount, as we want the fee amount to stay in the contract.
        usdc.approve(address(messenger), transferAmount);

        // Call deposit for burn and save the nonce.
        uint64 nonce = messenger.depositForBurn(transferAmount, destinationDomain, mintRecipient, burnToken);

        // As user already paid for the fee we emit the payment event.
        emit PaymentForRelay(nonce, feeAmount);
    }

    function swapAndRequestCCTPTransferWithCaller(
        address inputToken,
        uint256 inputAmount,
        bytes memory swapCalldata,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount,
        bytes32 destinationCaller
    ) external payable nonReentrant {
        if (inputAmount == 0) revert PaymentCannotBeZero();
        if (feeAmount == 0) revert PaymentCannotBeZero();

        uint256 outputAmount;
        if (inputToken == address(0)) {
            // Native Token
            if (inputAmount != msg.value) revert InsufficientNativeToken();

            IERC20 token = IERC20(inputToken);

            // Get the contract's balances previous to the swap
            uint256 preInputBalance = address(this).balance - inputAmount;
            uint256 preOutputBalance = usdc.balanceOf(address(this));

            // Call the swap router and perform the swap
            (bool success,) = swapRouter.call{value: inputAmount}(swapCalldata);
            if (!success) revert SwapFailed();

            // Get the contract's balances after the swap
            uint256 postInputBalance = address(this).balance;
            uint256 postOutputBalance = usdc.balanceOf(address(this));

            // Check that the contract's native token balance has increased
            if (preOutputBalance >= postOutputBalance) revert InsufficientSwapOutput();
            outputAmount = postOutputBalance - preOutputBalance;

            // Refund the remaining ETH
            uint256 dust = postInputBalance - preInputBalance;
            if (dust != 0) {
                (bool ethSuccess,) = msg.sender.call{value: dust}("");
                if (!ethSuccess) revert ETHSendFailed();
            }
        } else {
            IERC20 token = IERC20(inputToken);

            // Get the contract's balances previous to the swap
            uint256 preInputBalance = token.balanceOf(address(this));
            uint256 preOutputBalance = usdc.balanceOf(address(this));

            // Transfer input ERC20 tokens to the contract
            token.transferFrom(msg.sender, address(this), inputAmount);

            // Approve the swap router to spend the input tokens
            token.approve(swapRouter, inputAmount);

            // Call the swap router and perform the swap
            (bool success,) = swapRouter.call(swapCalldata);
            if (!success) revert SwapFailed();

            // Get the contract's balances after the swap
            uint256 postInputBalance = token.balanceOf(address(this));
            uint256 postOutputBalance = usdc.balanceOf(address(this));

            // Check that the contract's output token balance has increased
            if (preOutputBalance >= postOutputBalance) revert InsufficientSwapOutput();
            outputAmount = postOutputBalance - preOutputBalance;

            // Refund the remaining amount
            uint256 dust = postInputBalance - preInputBalance;
            if (dust != 0) {
                token.transfer(msg.sender, dust);

                // Revoke Approval
                token.approve(swapRouter, 0);
            }
        }

        // Check that output amount is enough to cover the fee
        if (outputAmount <= feeAmount) revert InsufficientSwapOutput();
        uint256 transferAmount = outputAmount - feeAmount;

        // Only give allowance of the transfer amount, as we want the fee amount to stay in the contract.
        usdc.approve(address(messenger), transferAmount);

        // Call deposit for burn and save the nonce.
        uint64 nonce = messenger.depositForBurnWithCaller(
            transferAmount, destinationDomain, mintRecipient, burnToken, destinationCaller
        );

        // As user already paid for the fee we emit the payment event.
        emit PaymentForRelay(nonce, feeAmount);
    }

    function swapAndRequestCCTPWithSolanaSwap(
        address inputToken,
        uint256 inputAmount,
        bytes memory swapCalldata,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount,
        bytes32 destinationCaller,
        bytes memory solanaSwapPayload
    ) external payable nonReentrant {
        if (inputAmount == 0) revert PaymentCannotBeZero();
        if (feeAmount == 0) revert PaymentCannotBeZero();
        if (destinationDomain != 5) revert InvalidDomain(); // restrict domain to Solana

        uint256 outputAmount;
        if (inputToken == address(0)) {
            // Native Token
            if (inputAmount != msg.value) revert InsufficientNativeToken();

            // Get the contract's balances previous to the swap
            uint256 preInputBalance = address(this).balance - inputAmount;
            uint256 preOutputBalance = usdc.balanceOf(address(this));

            // Call the swap router and perform the swap
            (bool success,) = swapRouter.call{value: inputAmount}(swapCalldata);
            if (!success) revert SwapFailed();

            // Get the contract's balances after the swap
            uint256 postInputBalance = address(this).balance;
            uint256 postOutputBalance = usdc.balanceOf(address(this));

            // Check that the contract's native token balance has increased
            if (preOutputBalance >= postOutputBalance) revert InsufficientSwapOutput();
            outputAmount = postOutputBalance - preOutputBalance;

            // Refund the remaining ETH
            uint256 dust = postInputBalance - preInputBalance;
            if (dust != 0) {
                (bool ethSuccess,) = msg.sender.call{value: dust}("");
                if (!ethSuccess) revert ETHSendFailed();
            }
        } else {
            IERC20 token = IERC20(inputToken);

            // Get the contract's balances previous to the swap
            uint256 preInputBalance = token.balanceOf(address(this));
            uint256 preOutputBalance = usdc.balanceOf(address(this));

            // Transfer input ERC20 tokens to the contract
            token.transferFrom(msg.sender, address(this), inputAmount);

            // Approve the swap router to spend the input tokens
            token.approve(swapRouter, inputAmount);

            // Call the swap router and perform the swap
            (bool success,) = swapRouter.call(swapCalldata);
            if (!success) revert SwapFailed();

            // Get the contract's balances after the swap
            uint256 postInputBalance = token.balanceOf(address(this));
            uint256 postOutputBalance = usdc.balanceOf(address(this));

            // Check that the contract's output token balance has increased
            if (preOutputBalance >= postOutputBalance) revert InsufficientSwapOutput();
            outputAmount = postOutputBalance - preOutputBalance;

            // Refund the remaining amount
            uint256 dust = postInputBalance - preInputBalance;
            if (dust != 0) {
                token.transfer(msg.sender, dust);

                // Revoke Approval
                token.approve(swapRouter, 0);
            }
        }

        // Check that output amount is enough to cover the fee
        if (outputAmount <= feeAmount) revert InsufficientSwapOutput();
        uint256 transferAmount = outputAmount - feeAmount;

        // Only give allowance of the transfer amount, as we want the fee amount to stay in the contract.
        usdc.approve(address(messenger), transferAmount);

        // Call deposit for burn and save the nonce.
        uint64 nonce = messenger.depositForBurnWithCaller(
            transferAmount, destinationDomain, mintRecipient, burnToken, destinationCaller
        );

        // As user already paid for the fee we emit the payment event.
        emit PaymentForRelay(nonce, feeAmount);

        transmitter.sendMessageWithCaller(
            destinationDomain, mintRecipient, destinationCaller, abi.encodePacked(nonce, solanaSwapPayload)
        );
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

    function mintAndSwap(ICCTPRelayer.ReceiveCall memory transferCall, ICCTPRelayer.ReceiveCall memory swapCall)
        external
    {
        transmitter.receiveMessage(transferCall.message, transferCall.attestation);
        transmitter.receiveMessage(swapCall.message, swapCall.attestation);
    }

    function handleReceiveMessage(uint32, bytes32, bytes calldata messageBody) public returns (bool) {
        if (msg.sender != address(transmitter)) {
            revert SenderMustBeMessageTransmitter();
        }

        // IMPORTANT: right now there is no validation that the amountIn matches the amount actually transferred
        // if this is ever used in production, this should be added.
        (uint256 amountIn, address recipient, bytes memory swapCalldata) =
            abi.decode(messageBody, (uint256, address, bytes));

        usdc.approve(swapRouter, amountIn);

        (bool success,) = swapRouter.call(swapCalldata);
        if (success) {
            return true;
        }

        usdc.transfer(recipient, amountIn);

        return true;
    }

    function withdraw(address receiver, uint256 amount) external onlyOwner {
        // Check that the contract has enough balance.
        if (usdc.balanceOf(address(this)) < amount) revert MissingBalance();

        // Check that the transfer succeeds.
        if (!usdc.transfer(receiver, amount)) revert TransferFailed();
    }

    fallback() external payable {}

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
