// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PoolLibrary errors
/// @author Tigran Arakelyan
abstract contract PoolLibraryErrors {
    error InvalidIndex();
    error InvalidHolder();
    error ZeroAmount();
    error WrongUnlockTime();
}
