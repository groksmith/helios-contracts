// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is ERC20 {
    constructor(
        address _poolDelegate,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _maxInvestmentSize,
        uint256 _minInvestmentSize,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol){
    }
}