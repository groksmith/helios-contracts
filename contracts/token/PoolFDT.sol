// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./BasicFDT.sol";

import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract PoolFDT is BasicFDT {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SignedSafeMath for int256;
    using SafeMathInt for int256;

    uint256 public interestSum; // Sum of all withdrawable interest.
    uint256 public interestBalance; // The amount of earned interest present and accounted for in this contract.

    event BalanceUpdated(
        address indexed liquidityProvider,
        address indexed token,
        uint256 balance
    );

    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) BasicFDT(tokenName, tokenSymbol) {}

    function _updateFundsTokenBalance() internal override returns (int256) {
        uint256 _prevFundsTokenBalance = interestBalance;
        interestBalance = interestSum;
        return int256(interestBalance).sub(int256(_prevFundsTokenBalance));
    }
}
