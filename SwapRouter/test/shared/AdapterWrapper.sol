// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAdapter} from "../../src/interfaces/IAdapter.sol";

// AdapterWrapper is a helper contract that allows us to test adapters by delegating calls to them.
// It differs from the EntryPoint contract in that it only tests the adapter's functionality, not
// the EntryPoint's (such as slippage checks)
contract AdapterWrapper {
    address public adapter;

    constructor(address _adapter) {
        adapter = _adapter;
    }

    function swapExactIn(address tokenIn, address tokenOut, uint256 amountIn, bytes calldata data)
        external
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        (bool success, bytes memory returnData) =
            adapter.delegatecall(abi.encodeWithSelector(IAdapter.swapExactIn.selector, amountIn, data));

        if (!success) {
            _revertWithData(returnData);
        }

        amountOut = abi.decode(returnData, (uint256));

        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }

    function getAmountOut(uint256 amountIn, bytes calldata data) external view returns (uint256 amountOut) {
        (bool success, bytes memory returnData) =
            adapter.staticcall(abi.encodeWithSelector(IAdapter.getAmountOut.selector, amountIn, data));

        if (!success) {
            _revertWithData(returnData);
        }

        amountOut = abi.decode(returnData, (uint256));
    }

    function getAmountIn(uint256 amountOut, bytes calldata data) external view returns (uint256 amountIn) {
        (bool success, bytes memory returnData) =
            adapter.staticcall(abi.encodeWithSelector(IAdapter.getAmountIn.selector, amountOut, data));

        if (!success) {
            _revertWithData(returnData);
        }

        amountIn = abi.decode(returnData, (uint256));
    }

    function _revertWithData(bytes memory data) private pure {
        assembly {
            revert(add(data, 32), mload(data))
        }
    }
}
