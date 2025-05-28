// SPDX-License-Identifier: UNLICENSED
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ISwapRouter02} from "../interfaces/ISwapRouter02.sol";
import {BytesLib, Path} from "./Path.sol";

pragma solidity >= 0.8.18;

library SkipSwapRouter {
    using SafeERC20 for IERC20;
    using Path for bytes;

    error InsufficientOutputAmount();
    error NativePaymentFailed();

    function swap(
        address router,
        address destination,
        address inputToken,
        address outputToken,
        uint256 amountIn,
        bytes memory swapData
    ) public returns (uint256 amountOut) {
        uint256 preBalIn = IERC20(inputToken).balanceOf(address(this)) - amountIn;

        uint256 preBalOut =
            outputToken == address(0) ? address(this).balance : IERC20(outputToken).balanceOf(address(this));

        IERC20(inputToken).forceApprove(router, amountIn);

        (bool success, bytes memory returnData) = router.call(swapData);

        if (!success) {
            _revertWithData(returnData);
        }

        if (outputToken == address(0)) {
            amountOut = address(this).balance - preBalOut;
        } else {
            amountOut = IERC20(outputToken).balanceOf(address(this)) - preBalOut;
        }

        uint256 dust = IERC20(inputToken).balanceOf(address(this)) - preBalIn;

        if (dust != 0) {
            IERC20(inputToken).forceApprove(router, 0);
            IERC20(inputToken).safeTransfer(destination, dust);
        }
    }

    function sendNative(address token, uint256 amount, address destination) external {
        // Unwrap native token.
        IWETH weth = IWETH(token);
        weth.withdraw(amount);

        // Send it unwrapped to the destination
        (bool success,) = destination.call{value: amount}("");

        if (!success) {
            revert NativePaymentFailed();
        }
    }

    function _fixPath(address tokenA, address tokenB, bytes memory path) internal pure returns (bytes memory) {
        (address decodedA,,) = path.decodeFirstPool();
        if (decodedA != tokenA) {
            path = BytesLib.concat(BytesLib.toBytes(tokenA), BytesLib.slice(path, 20, path.length - 20));
        }

        (, address decodedB,) = path.decodeLastPool();
        if (decodedB != tokenB) {
            path = BytesLib.concat(BytesLib.slice(path, 0, path.length - 20), BytesLib.toBytes(tokenB));
        }

        return path;
    }

    function _fixPath(address tokenA, address tokenB, address[] memory path) internal pure returns (address[] memory) {
        if (path[0] != tokenA) {
            path[0] = tokenA;
        }

        uint256 lastElement = path.length - 1;
        if (path[lastElement] != tokenB) {
            path[lastElement] = tokenB;
        }

        return path;
    }

    function _revertWithData(bytes memory data) private pure {
        assembly {
            revert(add(data, 32), mload(data))
        }
    }
}
