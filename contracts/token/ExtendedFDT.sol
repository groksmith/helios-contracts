// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "../math/SafeMathInt.sol";
import "../math/SafeMathUint.sol";
import "./BasicFDT.sol";

abstract contract ExtendedFDT is BasicFDT {
    using SafeMath       for uint256;
    using SafeMathUint   for uint256;
    using SignedSafeMath for int256;
    using SafeMathInt    for int256;

    uint256 internal lossesPerShare;

    mapping(address => int256)  internal lossesCorrection;
    mapping(address => uint256) internal recognizedLosses;

    event LossesPerShareUpdated(uint256 lossesPerShare);
    event LossesCorrectionUpdated(address indexed account, int256 lossesCorrection);
    event LossesDistributed(address indexed by, uint256 lossesDistributed);
    event LossesRecognized(address indexed by, uint256 lossesRecognized, uint256 totalLossesRecognized);

    constructor(string memory tokenName, string memory tokenSymbol) BasicFDT(tokenName, tokenSymbol) {}

    function _distributeLosses(uint256 value) internal {
        require(totalSupply() > 0, "FDT:ZERO_SUPPLY");

        if (value == 0) return;

        uint256 _lossesPerShare = lossesPerShare.add(value.mul(POINTS_MULTIPLIER) / totalSupply());
        lossesPerShare = _lossesPerShare;

        emit LossesDistributed(msg.sender, value);
        emit LossesPerShareUpdated(_lossesPerShare);
    }

    function _prepareLossesWithdraw() internal returns (uint256 recognizableDividend) {
        recognizableDividend = recognizableLossesOf(msg.sender);

        uint256 _recognizedLosses = recognizedLosses[msg.sender].add(recognizableDividend);
        recognizedLosses[msg.sender] = _recognizedLosses;

        emit LossesRecognized(msg.sender, recognizableDividend, _recognizedLosses);
    }

    function recognizableLossesOf(address owner) public view returns (uint256) {
        return accumulativeLossesOf(owner).sub(recognizedLosses[owner]);
    }

    function recognizedLossesOf(address owner) external view returns (uint256) {
        return recognizedLosses[owner];
    }

    function accumulativeLossesOf(address owner) public view returns (uint256) {
        return lossesPerShare
        .mul(balanceOf(owner))
        .toInt256Safe()
        .add(lossesCorrection[owner])
        .toUint256Safe() / POINTS_MULTIPLIER;
    }

    function _transfer(address from, address to, uint256 value) internal virtual override {
        super._transfer(from, to, value);

        int256 _lossesCorrection = lossesPerShare.mul(value).toInt256Safe();
        int256 lossesCorrectionFrom = lossesCorrection[from].add(_lossesCorrection);
        lossesCorrection[from] = lossesCorrectionFrom;
        int256 lossesCorrectionTo = lossesCorrection[to].sub(_lossesCorrection);
        lossesCorrection[to] = lossesCorrectionTo;

        emit LossesCorrectionUpdated(from, lossesCorrectionFrom);
        emit LossesCorrectionUpdated(to, lossesCorrectionTo);
    }

    function _mint(address account, uint256 value) internal virtual override {
        super._mint(account, value);

        int256 _lossesCorrection = lossesCorrection[account].sub(
            (lossesPerShare.mul(value)).toInt256Safe()
        );

        lossesCorrection[account] = _lossesCorrection;

        emit LossesCorrectionUpdated(account, _lossesCorrection);
    }

    function _burn(address account, uint256 value) internal virtual override {
        super._burn(account, value);

        int256 _lossesCorrection = lossesCorrection[account].add(
            (lossesPerShare.mul(value)).toInt256Safe()
        );

        lossesCorrection[account] = _lossesCorrection;

        emit LossesCorrectionUpdated(account, _lossesCorrection);
    }

    function updateLossesReceived() public virtual {
        int256 newLosses = _updateLossesBalance();

        if (newLosses <= 0) return;

        _distributeLosses(newLosses.toUint256Safe());
    }

    function _recognizeLosses() internal virtual returns (uint256 losses) {}

    function _updateLossesBalance() internal virtual returns (int256) {}
}