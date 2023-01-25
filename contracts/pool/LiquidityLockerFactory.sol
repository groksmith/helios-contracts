// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./LiquidityLocker.sol";
import "../interfaces/ISubFactory.sol";
import "../interfaces/ILiquidityLockerFactory.sol";

// LiquidityLockerFactory instantiates LiquidityLockers
contract LiquidityLockerFactory is ILiquidityLockerFactory {
    uint8 constant LIQ_LOCKER_FACTORY = 1;

    mapping(address => address) public owner;     // Mapping of LiquidityLocker addresses to their owner (i.e owner[locker] = Owner of the LiquidityLocker).
    mapping(address => bool)    public isLocker;  // True only if a LiquidityLocker was created by this factory.

    function factoryType() external override pure returns (uint8) {
        return LIQ_LOCKER_FACTORY;
    }

    event LiquidityLockerCreated(address indexed owner, address liquidityLocker, address liquidityAsset);

    // Instantiates a LiquidityLocker contract
    function newLocker(address liquidityAsset) external override returns (address liquidityLocker) {
        liquidityLocker = address(new LiquidityLocker(liquidityAsset, msg.sender));
        owner[liquidityLocker] = msg.sender;
        isLocker[liquidityLocker] = true;

        emit LiquidityLockerCreated(msg.sender, liquidityLocker, liquidityAsset);
    }
}