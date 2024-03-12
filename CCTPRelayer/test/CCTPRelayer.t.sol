pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "script/Config.sol";

import {CCTPRelayer} from "src/CCTPRelayer.sol";
import {ITokenMessenger} from "src/interfaces/ITokenMessenger.sol";
import {IMessageTransmitter} from "src/interfaces/IMessageTransmitter.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CCTPRelayerTest is Test {
    using stdStorage for StdStorage;

    address public ACTOR_1 = makeAddr("ACTOR 1");

    uint256[] public forks;

    // Contracts from the selected fork
    CCTPRelayer public relayer;
    IERC20 public usdc;
    ITokenMessenger messenger;
    IMessageTransmitter transmitter;

    // Fork ID -> Contract
    mapping(uint256 => CCTPRelayer) public relayers;
    mapping(uint256 => IERC20) public usdcs;
    mapping(uint256 => ITokenMessenger) public messengers;
    mapping(uint256 => IMessageTransmitter) public transmitters;

    function setUp() public {
        uint256 id = vm.createSelectFork(vm.envString("RPC_MAINNET"), 19421470);
        usdcs[id] = IERC20(USDC_MAINNET);
        messengers[id] = ITokenMessenger(MESSENGER_MAINNET);
        transmitters[id] = IMessageTransmitter(TRANSMITTER_MAINNET);
        _deploy(id);
        forks.push(id);

        id = vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 42820450);
        usdcs[id] = IERC20(USDC_AVALANCHE);
        messengers[id] = ITokenMessenger(MESSENGER_AVALANCHE);
        transmitters[id] = IMessageTransmitter(TRANSMITTER_AVALANCHE);
        _deploy(id);
        forks.push(id);

        id = vm.createSelectFork(vm.envString("RPC_OP"), 117339078);
        usdcs[id] = IERC20(USDC_OP);
        messengers[id] = ITokenMessenger(MESSENGER_OP);
        transmitters[id] = IMessageTransmitter(TRANSMITTER_OP);
        _deploy(id);
        forks.push(id);

        id = vm.createSelectFork(vm.envString("RPC_ARBITRUM"), 189738155);
        usdcs[id] = IERC20(USDC_ARBITRUM);
        messengers[id] = ITokenMessenger(MESSENGER_ARBITRUM);
        transmitters[id] = IMessageTransmitter(TRANSMITTER_ARBITRUM);
        _deploy(id);
        forks.push(id);

        id = vm.createSelectFork(vm.envString("RPC_BASE"), 11743812);
        usdcs[id] = IERC20(USDC_BASE);
        messengers[id] = ITokenMessenger(MESSENGER_BASE);
        transmitters[id] = IMessageTransmitter(TRANSMITTER_BASE);
        _deploy(id);
        forks.push(id);

        id = vm.createSelectFork(vm.envString("RPC_POLYGON"), 54583257);
        usdcs[id] = IERC20(USDC_POLYGON);
        messengers[id] = ITokenMessenger(MESSENGER_POLYGON);
        transmitters[id] = IMessageTransmitter(TRANSMITTER_POLYGON);
        _deploy(id);
        forks.push(id);
    }

    function test_Fuzz_makePaymentForRelay(uint64 nonce, uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);
        uint256 length = forks.length;

        for (uint256 i; i < length; ++i) {
            _switchFork(forks[i]);
            _paymentForRelay(nonce, amount);
        }
    }

    function test_requestCCTPTransfer() public {
        uint256 length = forks.length;

        uint32[6] memory domains = [uint32(0), 1, 2, 3, 6, 7];

        for (uint256 i; i < length; ++i) {
            _switchFork(forks[i]);
            _requestCCTPTransfer(domains[5 - i]);
        }
    }

    function test_withdraw() public {
        uint256 length = forks.length;

        address receiver = makeAddr("RECEIVER");

        for (uint256 i; i < length; ++i) {
            uint256 amount = 10 * (i + 1) * 1e6;
            _switchFork(forks[i]);
            _paymentForRelay(uint64(i), amount);

            relayer.withdraw(receiver, amount);
            assertEq(usdc.balanceOf(receiver), amount, "Withdrawal not transferred");
        }
    }

    function _requestCCTPTransfer(uint32 domain) internal {
        uint256 transferAmount = 1_000 * 1e6;
        uint256 feeAmount = 10 * 1e6;
        uint256 amount = transferAmount + feeAmount;

        _dealUSDC(ACTOR_1, amount);
        assertEq(usdc.balanceOf(ACTOR_1), amount, "Balance Before Payment is Wrong");

        bytes32 mintRecipent = bytes32(abi.encodePacked(ACTOR_1));

        vm.startPrank(ACTOR_1);
        usdc.approve(address(relayer), amount);
        relayer.requestCCTPTransfer(transferAmount, domain, mintRecipent, address(usdc), feeAmount);
        vm.stopPrank();

        assertEq(usdc.allowance(address(relayer), address(messenger)), 0, "Messenger Allowance Remaining After Payment");
        assertEq(usdc.allowance(ACTOR_1, address(relayer)), 0, "Relayer Allowance Remaining After Payment");
        assertEq(usdc.balanceOf(ACTOR_1), 0, "Balance Remaining After Payment");
    }

    function _switchFork(uint256 id) internal {
        vm.selectFork(id);

        relayer = relayers[id];
        usdc = usdcs[id];
        messenger = messengers[id];
        transmitter = transmitters[id];
    }

    function _deploy(uint256 id) internal {
        CCTPRelayer relayerImpl = new CCTPRelayer();
        ERC1967Proxy relayerProxy = new ERC1967Proxy(
            address(relayerImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                address(usdcs[id]),
                address(messengers[id]),
                address(transmitters[id])
            )
        );

        relayers[id] = CCTPRelayer(address(relayerProxy));
        relayer = CCTPRelayer(address(relayerProxy));
    }

    function _dealUSDC(address account, uint256 amount) internal {
        vm.store(address(usdc), keccak256(abi.encode(account, uint256(9))), bytes32(amount));
    }

    function _paymentForRelay(uint64 nonce, uint256 amount) internal {
        _dealUSDC(ACTOR_1, amount);
        assertEq(usdc.balanceOf(ACTOR_1), amount, "Balance Before Payment is Wrong");

        vm.startPrank(ACTOR_1);
        usdc.approve(address(relayer), amount);
        relayer.makePaymentForRelay(nonce, amount);
        vm.stopPrank();

        assertEq(usdc.allowance(ACTOR_1, address(relayer)), 0, "Allowance Remaining After Payment");
        assertEq(usdc.balanceOf(ACTOR_1), 0, "Balance Remaining After Payment");
    }
}
