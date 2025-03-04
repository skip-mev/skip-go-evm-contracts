// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IICS20TransferMsgs, IICS20Transfer} from "./interfaces/eureka/ICS20Transfer.sol";
import {IIBCVoucher} from "./interfaces/lombard/IIBCVoucher.sol";
import {IEurekaHandler} from "./interfaces/IEurekaHandler.sol";

contract EurekaHandler is IEurekaHandler {
    address public ics20Transfer;
    address public swapRouter;
    address public lbtcVoucher;
    address public lbtc;

    event Transfer(address indexed token, uint256 amount, uint256 relayFee, uint256 protocolFee);

    constructor(address _ics20Transfer, address _swapRouter, address _lbtcVoucher, address _lbtc) {
        ics20Transfer = _ics20Transfer;
        swapRouter = _swapRouter;
        lbtcVoucher = _lbtcVoucher;
        lbtc = _lbtc;
    }

    function transfer(uint256 amount, TransferParams memory transferParams, Fees memory fees) external {
        require(block.timestamp < fees.quoteExpiry, "Fee quote expired");

        _collectFees(transferParams.token, msg.sender, fees);

        IERC20(transferParams.token).transferFrom(msg.sender, address(this), amount);

        _sendTransfer(
            IICS20TransferMsgs.SendTransferMsg({
                denom: transferParams.token,
                amount: amount,
                receiver: transferParams.recipient,
                sourceClient: transferParams.sourceClient,
                destPort: transferParams.destPort,
                timeoutTimestamp: transferParams.timeoutTimestamp,
                memo: transferParams.memo
            })
        );

        emit Transfer(transferParams.token, amount, fees.relayFee, fees.protocolFee);
    }

    function swapAndTransfer(
        address swapInputToken,
        uint256 swapInputAmount,
        bytes memory swapCalldata,
        TransferParams memory transferParams,
        Fees memory fees
    ) external {
        require(block.timestamp < fees.quoteExpiry, "Fee quote expired");

        IERC20(swapInputToken).transferFrom(msg.sender, address(this), swapInputAmount);

        uint256 amountOut = _swap(swapInputToken, transferParams.token, swapInputAmount, swapCalldata);

        if (amountOut < _totalFees(fees)) {
            revert("Insufficient amount out to cover fees");
        }

        uint256 amountOutAfterFees = amountOut - _totalFees(fees);

        _sendTransfer(
            IICS20TransferMsgs.SendTransferMsg({
                denom: transferParams.token,
                amount: amountOutAfterFees,
                receiver: transferParams.recipient,
                sourceClient: transferParams.sourceClient,
                destPort: transferParams.destPort,
                timeoutTimestamp: transferParams.timeoutTimestamp,
                memo: transferParams.memo
            })
        );

        emit Transfer(transferParams.token, amountOutAfterFees, fees.relayFee, fees.protocolFee);
    }

    function lombardTransfer(uint256 amount, TransferParams memory transferParams, Fees memory fees) external {
        require(block.timestamp < fees.quoteExpiry, "Fee quote expired");

        _collectFees(lbtc, msg.sender, fees);

        IERC20(lbtc).transferFrom(msg.sender, address(this), amount);

        IERC20(lbtc).approve(lbtcVoucher, amount);

        uint256 voucherAmount = IIBCVoucher(lbtcVoucher).get(amount);

        _sendTransfer(
            IICS20TransferMsgs.SendTransferMsg({
                denom: lbtcVoucher,
                amount: voucherAmount,
                receiver: transferParams.recipient,
                sourceClient: transferParams.sourceClient,
                destPort: transferParams.destPort,
                timeoutTimestamp: transferParams.timeoutTimestamp,
                memo: transferParams.memo
            })
        );

        emit Transfer(lbtc, voucherAmount, fees.relayFee, fees.protocolFee);
    }

    function _collectFees(address token, address sender, Fees memory fees) internal {
        uint256 totalFees = _totalFees(fees);

        IERC20(token).transferFrom(sender, address(this), totalFees);
    }

    function _sendTransfer(IICS20TransferMsgs.SendTransferMsg memory transferMsg) internal {
        IERC20(transferMsg.denom).approve(ics20Transfer, transferMsg.amount);

        IICS20Transfer(ics20Transfer).sendTransferWithSender(transferMsg, msg.sender);
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn, bytes memory swapCalldata)
        internal
        returns (uint256 amountOut)
    {
        uint256 tokenOutBalanceBefore = IERC20(tokenOut).balanceOf(address(this));

        IERC20(tokenIn).approve(swapRouter, amountIn);

        (bool success,) = swapRouter.call(swapCalldata);
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - tokenOutBalanceBefore;

        return amountOut;
    }

    function _totalFees(Fees memory fees) internal pure returns (uint256) {
        return fees.relayFee + fees.protocolFee;
    }
}
