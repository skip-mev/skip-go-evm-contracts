// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IWETH} from "./interfaces/IWETH.sol";

import {IAxelarGasService} from "lib/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "lib/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract AxelarHandler is AxelarExecutable, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error EmptySymbol();

    string public immutable WETH_SYMBOL;

    IAxelarGasService public gasService;

    constructor(
        address axGateway,
        address axGasService,
        string calldata wethSymbol
    ) AxelarExecutable(axGateway) {
        if (axGasService == address(0)) revert ZeroAddress();
        if (bytes(wethSymbol).length == 0) revert EmptySymbol();

        gasService = IAxelarGasService(axGasService);
    }
}
