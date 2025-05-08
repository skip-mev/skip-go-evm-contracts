// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UniswapV2Adapter} from "../src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "../src/adapters/UniswapV3Adapter.sol";
import {SkipGoSwapRouter} from "../src/SkipGoSwapRouter.sol";

contract SkipGoSwapRouterTest is Test {
    uint256 mainnetFork;
    SkipGoSwapRouter public router;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("ETHEREUM_MAINNET_RPC_URL"), 22288910);

        vm.selectFork(mainnetFork);

        router = new SkipGoSwapRouter();

        UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
        router.addAdapter(1, address(uniswapV2Adapter));

        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();
        router.addAdapter(2, address(uniswapV3Adapter));
    }

    function test_swapExactIn() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                zeroToOne: false,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] = SkipGoSwapRouter.Hop({exchangeType: 1, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] = SkipGoSwapRouter.Hop({exchangeType: 2, data: encodedHopTwoData});
        }

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");

        deal(weth, alice, amountIn);

        uint256 expectedAmountOut = router.getAmountOut(amountIn, hops);

        uint256 wethBalanceBefore = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), amountIn);

        uint256 amountOut = router.swapExactIn(amountIn, 1, weth, wbtc, hops);

        vm.stopPrank();

        uint256 wethBalanceAfter = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        assertEq(wethBalanceAfter, wethBalanceBefore - amountIn);
        assertEq(wbtcBalanceAfter, wbtcBalanceBefore + amountOut);

        assertEq(amountOut, expectedAmountOut);
    }

    function test_revertSwapExactIn_WhenAmountOutIsLessThanAmountIn() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                zeroToOne: false,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] = SkipGoSwapRouter.Hop({exchangeType: 1, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] = SkipGoSwapRouter.Hop({exchangeType: 2, data: encodedHopTwoData});
        }

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");

        deal(weth, alice, amountIn);

        uint256 expectedAmountOut = router.getAmountOut(amountIn, hops);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), amountIn);

        vm.expectRevert("amount out is less than amount out min");
        router.swapExactIn(amountIn, expectedAmountOut + 1, weth, wbtc, hops);

        vm.stopPrank();
    }

    function test_swapExactOut() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                zeroToOne: false,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] = SkipGoSwapRouter.Hop({exchangeType: 1, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] = SkipGoSwapRouter.Hop({exchangeType: 2, data: encodedHopTwoData});
        }

        uint256 amountOut = 100000000;

        address alice = makeAddr("alice");

        uint256 expectedAmountIn = router.getAmountIn(amountOut, hops);

        deal(weth, alice, expectedAmountIn);

        uint256 wethBalanceBefore = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), expectedAmountIn);

        uint256 amountIn = router.swapExactOut(amountOut, type(uint256).max, weth, wbtc, hops);

        vm.stopPrank();

        uint256 wethBalanceAfter = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        assertEq(wethBalanceAfter, wethBalanceBefore - amountIn);
        assertEq(wbtcBalanceAfter, wbtcBalanceBefore + amountOut);

        assertEq(amountIn, expectedAmountIn);
    }

    function test_revertSwapExactOut_WhenAmountInIsGreaterThanAmountInMax() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                zeroToOne: false,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] = SkipGoSwapRouter.Hop({exchangeType: 1, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] = SkipGoSwapRouter.Hop({exchangeType: 2, data: encodedHopTwoData});
        }

        uint256 amountOut = 100000000;

        address alice = makeAddr("alice");

        uint256 expectedAmountIn = router.getAmountIn(amountOut, hops);

        deal(weth, alice, expectedAmountIn);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), expectedAmountIn);

        vm.expectRevert("amount in is greater than amount in max");
        router.swapExactOut(amountOut, expectedAmountIn - 1, weth, wbtc, hops);

        vm.stopPrank();
    }
}
