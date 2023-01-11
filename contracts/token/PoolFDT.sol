// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExtendedFDT.sol";

abstract contract PoolFDT is ExtendedFDT {
    using SafeMath       for uint256;
    using SafeMathUint   for uint256;
    using SignedSafeMath for int256;
    using SafeMathInt    for int256;

    uint256 public interestSum;  // Sum of all withdrawable interest.
    uint256 public poolLosses;   // Sum of all unrecognized losses.

    uint256 public interestBalance;  // The amount of earned interest present and accounted for in this contract.
    uint256 public lossesBalance;    // The amount of losses present and accounted for in this contract.

    constructor(string memory tokenName, string memory tokenSymbol) ExtendedFDT(tokenName, tokenSymbol) {
        interestSum = 0;
    }

    function _recognizeLosses() internal override returns (uint256 losses) {
        losses = _prepareLossesWithdraw();
        poolLosses = poolLosses.sub(losses);
        _updateLossesBalance();
    }

    function _updateLossesBalance() internal override returns (int256) {
        uint256 _prevLossesTokenBalance = lossesBalance;
        lossesBalance = poolLosses;
        return int256(lossesBalance).sub(int256(_prevLossesTokenBalance));
    }

    function _updateFundsTokenBalance() internal override returns (int256) {
        uint256 _prevFundsTokenBalance = interestBalance;
        interestBalance = interestSum;
        return int256(interestBalance).sub(int256(_prevFundsTokenBalance));
    }
}