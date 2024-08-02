// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import {BytesLib, Path} from "src/libraries/Path.sol";

contract PathTest is Test {
    using Path for bytes;

    function test_toBytes() public {
        address testAddr = makeAddr("test");
        bytes memory testAddrBytes = BytesLib.toBytes(testAddr);

        assertEq(testAddr, BytesLib.toAddress(testAddrBytes, 0), "Address to bytes lib");
        assertEq(testAddr, address(uint160(bytes20(testAddrBytes))), "Address to bytes typecast");
    }

    function test_decodeFirstPool() public {
        address token1 = makeAddr("TOKEN 1");
        address token2 = makeAddr("TOKEN 2");
        address token3 = makeAddr("TOKEN 3");

        bytes memory testPath = abi.encodePacked(token1, uint24(100), token2, uint24(3000), token3);

        (address tokenA, address tokenB, uint24 fee) = testPath.decodeFirstPool();

        assertEq(tokenA, token1, "Token A not properly decoded");
        assertEq(tokenB, token2, "Token B not properly decoded");
        assertEq(uint24(100), fee, "fee not properly decoded");
    }

    function test_decodeLastPool() public {
        address token1 = makeAddr("TOKEN 1");
        address token2 = makeAddr("TOKEN 2");
        address token3 = makeAddr("TOKEN 3");

        bytes memory testPath = abi.encodePacked(token1, uint24(100), token2, uint24(3000), token3);

        (address tokenA, address tokenB, uint24 fee) = testPath.decodeLastPool();

        assertEq(tokenA, token2, "Token A not properly decoded");
        assertEq(tokenB, token3, "Token B not properly decoded");
        assertEq(uint24(3000), fee, "fee not properly decoded");
    }
}
