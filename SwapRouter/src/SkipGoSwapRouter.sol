// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAdapter} from "./interfaces/IAdapter.sol";
import {IWETH} from "./interfaces/IWETH.sol";

contract SkipGoSwapRouter is Ownable {
    enum ExchangeType {
        UNISWAP_V2,
        UNISWAP_V3
    }

    mapping(ExchangeType => address) public adapters;

    address public weth;

    struct Hop {
        ExchangeType exchangeType;
        bytes data;
    }

    struct Affiliate {
        address recipient;
        uint256 feeBPS;
    }

    constructor(address _weth) Ownable(msg.sender) {
        weth = _weth;
    }

    receive() external payable {}

    function swapExactIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        Hop[] calldata hops,
        Affiliate[] calldata affiliates
    ) external payable returns (uint256 amountOut) {
        // if token in is ETH, msg.value must be equal to amountIn
        // if token in is not ETH, msg.value must be 0
        require(msg.value == (tokenIn == address(0) ? amountIn : 0), "invalid msg.value");

        if (tokenIn == address(0)) {
            IWETH(weth).deposit{value: amountIn}();
        } else {
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        }

        amountOut = amountIn;

        for (uint256 i = 0; i < hops.length; i++) {
            Hop memory hop = hops[i];

            address adapter = adapters[hop.exchangeType];

            if (adapter == address(0)) {
                revert("Adapter not found");
            }

            (bool success, bytes memory returnData) =
                adapter.delegatecall(abi.encodeWithSelector(IAdapter.swapExactIn.selector, amountOut, hop.data));

            if (!success) {
                _revertWithData(returnData);
            }

            amountOut = abi.decode(returnData, (uint256));
        }

        require(amountOut >= amountOutMin, "amount out is less than amount out min");

        uint256 amountPaid = _payAffiliateFees(tokenOut, amountOut, affiliates);

        amountOut = amountOut - amountPaid;

        if (tokenOut == address(0)) {
            IWETH(weth).withdraw(amountOut);
            payable(msg.sender).transfer(amountOut);
        } else {
            IERC20(tokenOut).transfer(msg.sender, amountOut);
        }
    }

    function swapExactOut(
        uint256 amountOut,
        uint256 amountInMax,
        address tokenIn,
        address tokenOut,
        Hop[] calldata hops,
        Affiliate[] calldata affiliates
    ) external payable returns (uint256 amountIn) {
        amountIn = getAmountIn(amountOut, hops);

        require(amountIn <= amountInMax, "amount in is greater than amount in max");

        if (tokenIn == address(0)) {
            require(msg.value >= amountIn, "msg.value is less than amount in");
            IWETH(weth).deposit{value: amountIn}();
        } else {
            require(msg.value == 0, "msg.value must be 0");
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        }

        amountOut = amountIn;

        for (uint256 i = 0; i < hops.length; i++) {
            Hop memory hop = hops[i];

            address adapter = adapters[hop.exchangeType];

            if (adapter == address(0)) {
                revert("Adapter not found");
            }

            (bool success, bytes memory returnData) =
                adapter.delegatecall(abi.encodeWithSelector(IAdapter.swapExactIn.selector, amountOut, hop.data));

            if (!success) {
                _revertWithData(returnData);
            }

            amountOut = abi.decode(returnData, (uint256));
        }

        uint256 amountPaid = _payAffiliateFees(tokenOut, amountOut, affiliates);

        uint256 amountOutAfterFees = amountOut - amountPaid;

        if (tokenOut == address(0)) {
            IWETH(weth).withdraw(amountOutAfterFees);
            payable(msg.sender).transfer(amountOutAfterFees);
        } else {
            IERC20(tokenOut).transfer(msg.sender, amountOutAfterFees);
        }

        // refund unused ETH
        if (tokenIn == address(0) && msg.value > amountIn) {
            payable(msg.sender).transfer(msg.value - amountIn);
        }
    }

    function getAmountOut(uint256 amountIn, Hop[] calldata hops) public view returns (uint256 amountOut) {
        amountOut = amountIn;
        for (uint256 i = 0; i < hops.length; i++) {
            Hop memory hop = hops[i];

            address adapter = adapters[hop.exchangeType];

            if (adapter == address(0)) {
                revert("Adapter not found");
            }

            amountOut = IAdapter(adapter).getAmountOut(amountOut, hop.data);
        }

        return amountOut;
    }

    function getAmountIn(uint256 amountOut, Hop[] calldata hops) public view returns (uint256 amountIn) {
        amountIn = amountOut;

        for (int256 i = int256(hops.length) - 1; i >= 0; i--) {
            Hop memory hop = hops[uint256(i)];

            address adapter = adapters[hop.exchangeType];

            if (adapter == address(0)) {
                revert("Adapter not found");
            }

            amountIn = IAdapter(adapter).getAmountIn(amountIn, hop.data);
        }

        return amountIn;
    }

    function addAdapter(ExchangeType exchangeType, address adapter) external onlyOwner {
        adapters[exchangeType] = adapter;
    }

    function _revertWithData(bytes memory data) private pure {
        assembly {
            revert(add(data, 32), mload(data))
        }
    }

    function _payAffiliateFees(address token, uint256 amount, Affiliate[] calldata affiliates)
        private
        returns (uint256 amountPaid)
    {
        for (uint256 i = 0; i < affiliates.length; i++) {
            Affiliate memory affiliate = affiliates[i];

            uint256 fee = (amount * affiliate.feeBPS) / 10000;

            amountPaid += fee;

            IERC20(token).transfer(affiliate.recipient, fee);
        }

        return amountPaid;
    }
}
