// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.1;

import "./LiquidityLocker.sol";

contract LiquidityLockerFactory {

    mapping(address => address) public owner;     // Mapping of LiquidityLocker addresses to their owner (i.e owner[locker] = Owner of the LiquidityLocker).
    mapping(address => bool)    public isLocker;  // True only if a LiquidityLocker was created by this factory.

    uint8 public constant factoryType = 1;

    event LiquidityLockerCreated(address indexed owner, address liquidityLocker, address liquidityAsset);

    function newLocker(address liquidityAsset) external returns (address liquidityLocker) {
        liquidityLocker = address(new LiquidityLocker(liquidityAsset, msg.sender));
        owner[liquidityLocker] = msg.sender;
        isLocker[liquidityLocker] = true;

        emit LiquidityLockerCreated(msg.sender, liquidityLocker, liquidityAsset);
    }
}