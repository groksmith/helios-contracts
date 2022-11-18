// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is ERC20 {
    address public poolDelegate;
    uint256 public lockupPeriod;
    uint256 public apy;
    uint256 public maxInvestmentSize;
    uint256 public minInvestmentSize;

    constructor(
        address _poolDelegate,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _maxInvestmentSize,
        uint256 _minInvestmentSize,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol){
        poolDelegate = _poolDelegate;
        lockupPeriod = _lockupPeriod;
        apy = _apy;
        maxInvestmentSize = _maxInvestmentSize;
        minInvestmentSize = _minInvestmentSize;
    }
}