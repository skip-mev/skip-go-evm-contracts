// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {UniswapV2Adapter} from "../src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "../src/adapters/UniswapV3Adapter.sol";
import {SkipGoSwapRouter} from "../src/SkipGoSwapRouter.sol";

contract SkipGoSwapRouterTest is Test {
    uint256 mainnetFork;
    SkipGoSwapRouter public router;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("ETHEREUM_MAINNET_RPC_URL"), 22288910);

        vm.selectFork(mainnetFork);

        SkipGoSwapRouter routerImpl = new SkipGoSwapRouter();

        ERC1967Proxy routerProxy = new ERC1967Proxy(
            address(routerImpl),
            abi.encodeWithSignature("initialize(address)", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        );

        router = SkipGoSwapRouter(payable(address(routerProxy)));

        UniswapV2Adapter uniswapV2Adapter = new UniswapV2Adapter();
        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V2, address(uniswapV2Adapter));

        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter();
        router.addAdapter(SkipGoSwapRouter.ExchangeType.UNISWAP_V3, address(uniswapV3Adapter));
    }

    function test_swapExactIn() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");

        deal(weth, alice, amountIn);

        uint256 expectedAmountOut = router.getAmountOut(amountIn, hops);

        uint256 wethBalanceBefore = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), amountIn);

        uint256 amountOut = router.swapExactIn(amountIn, 1, weth, wbtc, hops, affiliates);

        vm.stopPrank();

        uint256 wethBalanceAfter = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        assertEq(wethBalanceAfter, wethBalanceBefore - amountIn);
        assertEq(wbtcBalanceAfter, wbtcBalanceBefore + amountOut);

        assertEq(amountOut, expectedAmountOut);
    }

    function test_swapExactIn_WithWrapWETH() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");

        deal(alice, amountIn);

        uint256 expectedAmountOut = router.getAmountOut(amountIn, hops);

        uint256 ethBalanceBefore = address(alice).balance;
        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);

        vm.startPrank(alice);

        uint256 amountOut = router.swapExactIn{value: amountIn}(amountIn, 1, address(0), wbtc, hops, affiliates);

        vm.stopPrank();

        uint256 ethBalanceAfter = address(alice).balance;
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        assertEq(ethBalanceAfter, ethBalanceBefore - amountIn);
        assertEq(wbtcBalanceAfter, wbtcBalanceBefore + amountOut);

        assertEq(amountOut, expectedAmountOut);
    }

    function test_swapExactIn_WithUnwrapWETH() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV3Adapter.UniswapV3Data memory hopOneData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: wbtc,
                tokenOut: usdc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopOneData});

            UniswapV2Adapter.UniswapV2Data memory hopTwoData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: usdc,
                tokenOut: weth,
                fee: 300
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopTwoData});
        }

        uint256 amountIn = 1_0000_0000; // 1 BTC

        address alice = makeAddr("alice");

        deal(wbtc, alice, amountIn);

        uint256 expectedAmountOut = router.getAmountOut(amountIn, hops);

        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);
        uint256 ethBalanceBefore = address(alice).balance;

        vm.startPrank(alice);

        IERC20(wbtc).approve(address(router), amountIn);

        uint256 amountOut = router.swapExactIn(amountIn, 1, wbtc, address(0), hops, affiliates);

        vm.stopPrank();

        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);
        uint256 ethBalanceAfter = address(alice).balance;

        assertEq(wbtcBalanceAfter, wbtcBalanceBefore - amountIn);
        assertEq(ethBalanceAfter, ethBalanceBefore + amountOut);

        assertEq(amountOut, expectedAmountOut);
    }

    function test_swapExactIn_WithAffiliate() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        deal(weth, alice, amountIn);

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](1);

        {
            affiliates[0] = SkipGoSwapRouter.Affiliate({recipient: bob, feeBPS: 100});
        }

        uint256 expectedAmountOut = router.getAmountOut(amountIn, hops);

        uint256 expectedAffiliateFee = (expectedAmountOut * 100) / 10000;

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), amountIn);

        uint256 amountOut = router.swapExactIn(amountIn, 1, weth, wbtc, hops, affiliates);

        vm.stopPrank();

        uint256 wethBalanceAfter = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        uint256 bobWbtcBalanceAfter = IERC20(wbtc).balanceOf(bob);

        assertEq(wethBalanceAfter, 0);
        assertEq(wbtcBalanceAfter, amountOut);

        assertEq(amountOut, expectedAmountOut - expectedAffiliateFee);

        assertEq(bobWbtcBalanceAfter, expectedAffiliateFee);
    }

    function test_revertSwapExactIn_WhenAmountOutIsLessThanAmountIn() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountIn = 1 ether;

        address alice = makeAddr("alice");

        deal(weth, alice, amountIn);

        uint256 expectedAmountOut = router.getAmountOut(amountIn, hops);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), amountIn);

        vm.expectRevert("amount out is less than amount out min");
        router.swapExactIn(amountIn, expectedAmountOut + 1, weth, wbtc, hops, affiliates);

        vm.stopPrank();
    }

    function test_swapExactOut() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountOut = 100000000;

        address alice = makeAddr("alice");

        uint256 expectedAmountIn = router.getAmountIn(amountOut, hops);

        deal(weth, alice, expectedAmountIn);

        uint256 wethBalanceBefore = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), expectedAmountIn);

        uint256 amountIn = router.swapExactOut(amountOut, type(uint256).max, weth, wbtc, hops, affiliates);

        vm.stopPrank();

        uint256 wethBalanceAfter = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        assertEq(wethBalanceAfter, wethBalanceBefore - amountIn);
        assertEq(wbtcBalanceAfter, wbtcBalanceBefore + amountOut);

        assertEq(amountIn, expectedAmountIn);
    }

    function test_swapExactOut_WithWrapWETH() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountOut = 100000000;

        address alice = makeAddr("alice");

        uint256 expectedAmountIn = router.getAmountIn(amountOut, hops);

        deal(alice, expectedAmountIn + 500);

        uint256 ethBalanceBefore = address(alice).balance;
        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);

        vm.startPrank(alice);

        // set msg.value greater than expectedAmountIn to ensure dust is returned
        uint256 amountIn = router.swapExactOut{value: expectedAmountIn + 500}(
            amountOut, type(uint256).max, address(0), wbtc, hops, affiliates
        );

        vm.stopPrank();

        uint256 ethBalanceAfter = address(alice).balance;
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        assertEq(ethBalanceAfter, ethBalanceBefore - amountIn);
        assertEq(wbtcBalanceAfter, wbtcBalanceBefore + amountOut);

        assertEq(amountIn, expectedAmountIn);
    }

    function test_swapExactOut_WithUnwrapWETH() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV3Adapter.UniswapV3Data memory hopOneData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: wbtc,
                tokenOut: usdc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopOneData});

            UniswapV2Adapter.UniswapV2Data memory hopTwoData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: usdc,
                tokenOut: weth,
                fee: 300
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopTwoData});
        }

        uint256 amountOut = 1 ether;

        address alice = makeAddr("alice");

        uint256 expectedAmountIn = router.getAmountIn(amountOut, hops);

        deal(wbtc, alice, expectedAmountIn);

        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(alice);

        vm.startPrank(alice);

        IERC20(wbtc).approve(address(router), expectedAmountIn);

        uint256 amountIn = router.swapExactOut(amountOut, type(uint256).max, wbtc, address(0), hops, affiliates);

        vm.stopPrank();

        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        assertEq(wbtcBalanceAfter, wbtcBalanceBefore - amountIn);

        assertEq(amountIn, expectedAmountIn);
    }

    function test_swapExactOut_WithAffiliate() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountOut = 100000000;

        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        uint256 expectedAmountIn = router.getAmountIn(amountOut, hops);

        deal(weth, alice, expectedAmountIn);

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](1);

        {
            affiliates[0] = SkipGoSwapRouter.Affiliate({recipient: bob, feeBPS: 100});
        }

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), expectedAmountIn);

        uint256 amountIn = router.swapExactOut(amountOut, type(uint256).max, weth, wbtc, hops, affiliates);

        vm.stopPrank();

        uint256 expectedAffiliateFee = (amountOut * 100) / 10000;

        uint256 wethBalanceAfter = IERC20(weth).balanceOf(alice);
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(alice);

        uint256 bobWbtcBalanceAfter = IERC20(wbtc).balanceOf(bob);

        assertEq(wethBalanceAfter, 0);
        assertEq(wbtcBalanceAfter, amountOut - expectedAffiliateFee);

        assertEq(amountIn, expectedAmountIn);

        assertEq(bobWbtcBalanceAfter, expectedAffiliateFee);
    }

    function test_revertSwapExactOut_WhenAmountInIsGreaterThanAmountInMax() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        SkipGoSwapRouter.Affiliate[] memory affiliates = new SkipGoSwapRouter.Affiliate[](0);

        SkipGoSwapRouter.Hop[] memory hops = new SkipGoSwapRouter.Hop[](2);

        {
            UniswapV2Adapter.UniswapV2Data memory hopOneData = UniswapV2Adapter.UniswapV2Data({
                pool: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenIn: weth,
                tokenOut: usdc,
                fee: 300
            });

            bytes memory encodedHopOneData = abi.encode(hopOneData);

            hops[0] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V2, data: encodedHopOneData});

            UniswapV3Adapter.UniswapV3Data memory hopTwoData = UniswapV3Adapter.UniswapV3Data({
                tokenIn: usdc,
                tokenOut: wbtc,
                fee: 3000,
                quoter: 0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
                swapRouter: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
            });

            bytes memory encodedHopTwoData = abi.encode(hopTwoData);

            hops[1] =
                SkipGoSwapRouter.Hop({exchangeType: SkipGoSwapRouter.ExchangeType.UNISWAP_V3, data: encodedHopTwoData});
        }

        uint256 amountOut = 100000000;

        address alice = makeAddr("alice");

        uint256 expectedAmountIn = router.getAmountIn(amountOut, hops);

        deal(weth, alice, expectedAmountIn);

        vm.startPrank(alice);

        IERC20(weth).approve(address(router), expectedAmountIn);

        vm.expectRevert("amount in is greater than amount in max");
        router.swapExactOut(amountOut, expectedAmountIn - 1, weth, wbtc, hops, affiliates);

        vm.stopPrank();
    }
}
