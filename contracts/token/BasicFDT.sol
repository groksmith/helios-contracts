// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../math/SafeMathUint.sol";
import "../math/SafeMathInt.sol";

//import "hardhat/console.sol";

abstract contract BasicFDT is ERC20, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeMathInt for int256;
    using SignedSafeMath for int256;

    uint256 internal constant POINTS_MULTIPLIER = 1e18;
    uint256 internal pointsPerShare;
    uint256 internal totalMinted;

    mapping(address => int256) internal pointsCorrection;
    mapping(address => uint256) internal withdrawnFunds;
    mapping(address => uint256) internal accumulativeMintedFor;

    event PointsPerShareUpdated(uint256 pointsPerShare);
    event PointsCorrectionUpdated(
        address indexed account,
        int256 pointsCorrection
    );
    event FundsDistributed(address indexed by, uint256 fundsDistributed);
    event FundsWithdrawn(
        address indexed by,
        uint256 fundsWithdrawn,
        uint256 totalWithdrawn
    );

    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) {}

    function _distributeFunds(uint256 value) internal {
        require(totalSupply() > 0, "FDT:ZERO_SUPPLY");

        if (value == 0) return;

        pointsPerShare = pointsPerShare.add(
            value.mul(POINTS_MULTIPLIER) / totalSupply()
        );
        emit FundsDistributed(msg.sender, value);
        emit PointsPerShareUpdated(pointsPerShare);
    }

    //TODO to be deactivated
    function _prepareWithdraw()
        internal
        returns (uint256 withdrawableDividend)
    {
        withdrawableDividend = withdrawableFundsOf(msg.sender);
        uint256 _withdrawnFunds = withdrawnFunds[msg.sender].add(
            withdrawableDividend
        );
        withdrawnFunds[msg.sender] = _withdrawnFunds;

        emit FundsWithdrawn(msg.sender, withdrawableDividend, _withdrawnFunds);
    }

    function _prepareWithdraw(
        uint256 amount
    ) internal returns (uint256 withdrawableDividend) {
        withdrawableDividend = withdrawableFundsOf(msg.sender);
        require(amount <= withdrawableDividend, "FDT:INSUFFICIENT_FUNDS");
        uint256 _withdrawnFunds = withdrawnFunds[msg.sender].add(amount);
        withdrawnFunds[msg.sender] = _withdrawnFunds;

        emit FundsWithdrawn(msg.sender, withdrawableDividend, _withdrawnFunds);
    }

    function withdrawableFundsOf(address owner) public view returns (uint256) {
        return accumulativeFundsOf(owner).sub(withdrawnFunds[owner]);
    }

    function withdrawnFundsOf(address owner) external view returns (uint256) {
        return withdrawnFunds[owner];
    }

    function totalMintedFor(address owner) external view returns (uint256) {
        return accumulativeMintedFor[owner];
    }

    function accumulativeFundsOf(address owner) public view returns (uint256) {
        return
            pointsPerShare
                .mul(balanceOf(owner))
                .toInt256Safe()
                .add(pointsCorrection[owner])
                .toUint256Safe() / POINTS_MULTIPLIER;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        super._transfer(from, to, value);

        int256 _magCorrection = pointsPerShare.mul(value).toInt256Safe();
        int256 pointsCorrectionFrom = pointsCorrection[from].add(
            _magCorrection
        );
        pointsCorrection[from] = pointsCorrectionFrom;
        int256 pointsCorrectionTo = pointsCorrection[to].sub(_magCorrection);
        pointsCorrection[to] = pointsCorrectionTo;

        emit PointsCorrectionUpdated(from, pointsCorrectionFrom);
        emit PointsCorrectionUpdated(to, pointsCorrectionTo);
    }

    function _mint(address account, uint256 value) internal virtual override {
        super._mint(account, value);

        totalMinted = totalMinted.add(value);
        accumulativeMintedFor[account] = accumulativeMintedFor[account].add(
            value
        );

        int256 _pointsCorrection = pointsCorrection[account].sub(
            (pointsPerShare.mul(value)).toInt256Safe()
        );

        pointsCorrection[account] = _pointsCorrection;

        emit PointsCorrectionUpdated(account, _pointsCorrection);
    }

    function _burn(address account, uint256 value) internal virtual override {
        super._burn(account, value);

        int256 _pointsCorrection = pointsCorrection[account].add(
            (pointsPerShare.mul(value)).toInt256Safe()
        );

        pointsCorrection[account] = _pointsCorrection;

        emit PointsCorrectionUpdated(account, _pointsCorrection);
    }

    function withdrawFunds() public virtual {}

    function withdrawFundsAmount(uint256 amount) public virtual {}

    function _updateFundsTokenBalance() internal virtual returns (int256);

    function updateFundsReceived() public virtual {
        int256 newFunds = _updateFundsTokenBalance();

        if (newFunds <= 0) return;

        _distributeFunds(newFunds.toUint256Safe());
    }
}
