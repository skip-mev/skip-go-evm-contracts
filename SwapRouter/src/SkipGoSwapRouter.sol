// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAdapter} from "./interfaces/IAdapter.sol";

contract SkipGoSwapRouter {
    mapping(uint256 => address) public adapters;

    struct Hop {
        uint256 exchangeType;
        bytes data;
    }

    function swapExactIn(uint256 amountIn, uint256 amountOutMin, address tokenIn, address tokenOut, Hop[] calldata hops)
        external
        payable
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

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

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        return amountOut;
    }

    function swapExactOut(
        uint256 amountOut,
        uint256 amountInMax,
        address tokenIn,
        address tokenOut,
        Hop[] calldata hops
    ) external payable returns (uint256 amountIn) {
        amountIn = getAmountIn(amountOut, hops);

        require(amountIn <= amountInMax, "amount in is greater than amount in max");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

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

        IERC20(tokenOut).transfer(msg.sender, amountOut);
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

    function addAdapter(uint256 exchangeType, address adapter) external {
        adapters[exchangeType] = adapter;
    }

    function _revertWithData(bytes memory data) private pure {
        assembly {
            revert(add(data, 32), mload(data))
        }
    }
}
