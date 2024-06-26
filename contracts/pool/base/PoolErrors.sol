// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Pool errors
/// @author Tigran Arakelyan
abstract contract PoolErrors {
    error InvalidLiquidityAsset();
    error NotAdmin();
    error NotMultiSigAdmin();
    error NotPool();
    error Paused();
    error InvalidValue();
    error ZeroYield();
    error TokensLocked();
    error DepositAmountBelowMin();
    error InsufficientFunds();
    error BorrowedMoreThanDeposited();
    error CantRepayMoreThanBorrowed();
    error NotEnoughBalance();
    error TransferFailed();
    error NotEnoughAssets();
    error MaxPoolSizeReached();
    error BadState();
    error BlendedPoolAlreadyCreated();
    error BlendedPoolNotCreated();
    error PoolIdAlreadyExists();
    error NotBlendedPool();
    error InvalidIndex();
    error InvalidHolder();
    error ZeroAmount();
    error WrongUnlockTime();
}
