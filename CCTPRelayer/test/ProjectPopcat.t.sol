pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "script/Config.sol";

import {CCTPRelayer} from "src/CCTPRelayer.sol";
import {ICCTPRelayer} from "src/interfaces/ICCTPRelayer.sol";
import {ITokenMessenger} from "src/interfaces/ITokenMessenger.sol";
import {IMessageTransmitter} from "src/interfaces/IMessageTransmitter.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProjectPopcatTest is Test {
    using stdStorage for StdStorage;
    using stdJson for string;

    using stdStorage for StdStorage;
    using stdJson for string;

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    address public ACTOR_1 = makeAddr("ACTOR 1");

    uint256[] public forks;

    // Contracts from the selected fork
    CCTPRelayer public relayer;
    IERC20 public usdc;
    IERC20 public wETH;
    ITokenMessenger messenger;
    IMessageTransmitter transmitter;
    address public router;

    // Fork ID -> Contract
    mapping(uint256 => CCTPRelayer) public relayers;
    mapping(uint256 => IERC20) public usdcs;
    mapping(uint256 => ITokenMessenger) public messengers;
    mapping(uint256 => IMessageTransmitter) public transmitters;
    mapping(uint256 => address) public routers;
    mapping(uint256 => IERC20) public wETHs;

    uint256 attesterPK = 1;
    address attester = vm.addr(attesterPK);

    function setUp() public {
        string memory rpcsJson = vm.envString("RPC_ENDPOINTS");

        uint256 id = vm.createSelectFork(rpcsJson.readString(".ethereum-mainnet"));
        usdcs[id] = IERC20(USDC_MAINNET);
        wETHs[id] = IERC20(WETH_MAINNET);
        messengers[id] = ITokenMessenger(MESSENGER_MAINNET);
        transmitters[id] = IMessageTransmitter(TRANSMITTER_MAINNET);
        routers[id] = ROUTER_MAINNET;
        _deploy(id);
        forks.push(id);
    }

    function test_mintAndSwap() public {
        _switchFork(forks[0]);

        vm.startPrank(address(0x358a85e032aA9507a1303683b2B6A1d1cac3c252));
        transmitter.setSignatureThreshold(1);
        transmitter.enableAttester(attester);
        transmitter.disableAttester(0xb0Ea8E1bE37F346C7EA7ec708834D0db18A17361);
        transmitter.disableAttester(0xE2fEfe09E74b921CbbFF229E7cD40009231501CA);
        vm.stopPrank();

        bytes memory transferMessageBody = abi.encodePacked(
            uint32(0), // version
            _addressToBytes32(address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831)), // burnToken
            _addressToBytes32(address(relayer)), // mintRecipient
            uint256(100_000_000), // amount
            _addressToBytes32(address(0)) // messageSender
        );

        bytes memory transferMessage = _formatMessage(
            0, // version
            3, // sourceDomain
            0, // destinationDomain
            100878, // nonce
            _addressToBytes32(MESSENGER_ARBITRUM), // sender - TokenMessenger on source domain
            _addressToBytes32(address(messenger)), // recipient - TokenMessenger on destination domain
            _addressToBytes32(address(relayer)), // destinationCaller - Our contract
            transferMessageBody
        );

        bytes memory transferAttestation = _signMessageWithAttesterPK(transferMessage);

        ICCTPRelayer.ReceiveCall memory transferCall =
            ICCTPRelayer.ReceiveCall({message: transferMessage, attestation: transferAttestation});

        uint256 amountIn = 100000000;
        uint256 minAmount = 0;
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(wETH);
        bytes memory swapCalldata =
            abi.encodeWithSelector(bytes4(0x472b43f3), 100000000, minAmount, path, address(this));

        bytes memory swapMessageBody = abi.encode(amountIn, address(this), swapCalldata);

        bytes memory swapMessage = _formatMessage(
            0, // version
            3, // sourceDomain
            0, // destinationDomain
            100879, // nonce
            _addressToBytes32(MESSENGER_ARBITRUM), // sender - TokenMessenger on source domain
            _addressToBytes32(address(relayer)), // recipient - TokenMessenger on destination domain
            _addressToBytes32(address(relayer)), // destinationCaller - Our contract
            swapMessageBody
        );

        bytes memory swapAttestation = _signMessageWithAttesterPK(swapMessage);

        ICCTPRelayer.ReceiveCall memory swapCall =
            ICCTPRelayer.ReceiveCall({message: swapMessage, attestation: swapAttestation});

        uint256 wethBalanceBefore = wETH.balanceOf(address(this));

        relayer.mintAndSwap(transferCall, swapCall);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(this));
        uint256 wethBalanceAfter = wETH.balanceOf(address(this));

        assertEq(usdcBalanceAfter, 0);
        assertGt(wethBalanceAfter, wethBalanceBefore);
    }

    function test_mintAndSwapForwardsUSDCIfSwapFails() public {
        _switchFork(forks[0]);

        vm.startPrank(address(0x358a85e032aA9507a1303683b2B6A1d1cac3c252));
        transmitter.setSignatureThreshold(1);
        transmitter.enableAttester(attester);
        transmitter.disableAttester(0xb0Ea8E1bE37F346C7EA7ec708834D0db18A17361);
        transmitter.disableAttester(0xE2fEfe09E74b921CbbFF229E7cD40009231501CA);
        vm.stopPrank();

        bytes memory transferMessageBody = abi.encodePacked(
            uint32(0), // version
            _addressToBytes32(address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831)), // burnToken
            _addressToBytes32(address(relayer)), // mintRecipient
            uint256(100_000_000), // amount
            _addressToBytes32(address(0)) // messageSender
        );

        bytes memory transferMessage = _formatMessage(
            0, // version
            3, // sourceDomain
            0, // destinationDomain
            100878, // nonce
            _addressToBytes32(MESSENGER_ARBITRUM), // sender - TokenMessenger on source domain
            _addressToBytes32(address(messenger)), // recipient - TokenMessenger on destination domain
            _addressToBytes32(address(relayer)), // destinationCaller - Our contract
            transferMessageBody
        );

        bytes memory transferAttestation = _signMessageWithAttesterPK(transferMessage);

        ICCTPRelayer.ReceiveCall memory transferCall =
            ICCTPRelayer.ReceiveCall({message: transferMessage, attestation: transferAttestation});

        uint256 amountIn = 100000000;
        uint256 minAmount = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(wETH);
        bytes memory swapCalldata =
            abi.encodeWithSelector(bytes4(0x472b43f3), 100000000, minAmount, path, address(relayer));

        bytes memory swapMessageBody = abi.encode(amountIn, address(this), swapCalldata);

        bytes memory swapMessage = _formatMessage(
            0, // version
            3, // sourceDomain
            0, // destinationDomain
            100879, // nonce
            _addressToBytes32(MESSENGER_ARBITRUM), // sender - TokenMessenger on source domain
            _addressToBytes32(address(relayer)), // recipient - TokenMessenger on destination domain
            _addressToBytes32(address(relayer)), // destinationCaller - Our contract
            swapMessageBody
        );

        bytes memory swapAttestation = _signMessageWithAttesterPK(swapMessage);

        ICCTPRelayer.ReceiveCall memory swapCall =
            ICCTPRelayer.ReceiveCall({message: swapMessage, attestation: swapAttestation});

        relayer.mintAndSwap(transferCall, swapCall);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(this));
        uint256 wethBalanceAfter = wETH.balanceOf(address(this));

        assertEq(usdcBalanceAfter, 100_000_000);
        assertEq(wethBalanceAfter, 0);
    }

    function _switchFork(uint256 id) internal {
        vm.selectFork(id);

        relayer = relayers[id];
        usdc = usdcs[id];
        wETH = wETHs[id];
        messenger = messengers[id];
        transmitter = transmitters[id];
        router = routers[id];
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

        relayers[id] = CCTPRelayer(payable(address(relayerProxy)));
        relayer = CCTPRelayer(payable(address(relayerProxy)));

        relayer.setSwapRouter(routers[id]);
    }

    function _dealUSDC(address account, uint256 amount) internal {
        vm.store(address(usdc), keccak256(abi.encode(account, uint256(9))), bytes32(amount));
    }

    fallback() external payable {}

    receive() external payable {}

    function _formatMessage(
        uint32 _msgVersion,
        uint32 _msgSourceDomain,
        uint32 _msgDestinationDomain,
        uint64 _msgNonce,
        bytes32 _msgSender,
        bytes32 _msgRecipient,
        bytes32 _msgDestinationCaller,
        bytes memory _msgRawBody
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _msgVersion,
            _msgSourceDomain,
            _msgDestinationDomain,
            _msgNonce,
            _msgSender,
            _msgRecipient,
            _msgDestinationCaller,
            _msgRawBody
        );
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function _signMessageWithAttesterPK(bytes memory _message) internal view returns (bytes memory) {
        uint256[] memory attesterPrivateKeys = new uint256[](1);
        attesterPrivateKeys[0] = attesterPK;
        return _signMessage(_message, attesterPrivateKeys);
    }

    function _signMessage(bytes memory _message, uint256[] memory _privKeys) internal pure returns (bytes memory) {
        bytes memory _signaturesConcatenated = "";

        for (uint256 i = 0; i < _privKeys.length; i++) {
            uint256 _privKey = _privKeys[i];
            bytes32 _digest = keccak256(_message);
            (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_privKey, _digest);
            bytes memory _signature = abi.encodePacked(_r, _s, _v);

            _signaturesConcatenated = abi.encodePacked(_signaturesConcatenated, _signature);
        }

        return _signaturesConcatenated;
    }
}
