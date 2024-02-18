// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title PoolLibrary
/// @author Tigran Arakelyan
/// @notice Types and storage for holders and deposit information.
library PoolLibrary {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice General Pool information
    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
        uint256 withdrawThreshold;
    }

    /// @notice Single deposit info
    struct DepositInstance {
        uint256 amount;
        uint256 unlockTime;
    }

    /// @notice Holders and deposits
    /// @dev Trying to keep holders and lockedDeposits encapsulated and act as single unit
    struct DepositsStorage {
        EnumerableSet.AddressSet holders;

        mapping(address => DepositInstance[]) lockedDeposits;
    }

    /// @notice Get the count of holders
    function getHoldersCount(DepositsStorage storage self) external view returns (uint256) {
        return self.holders.length();
    }

    /// @notice Return true if holder exists
    function holderExists(DepositsStorage storage self, address holder) external view returns (bool) {
        return self.holders.contains(holder);
    }

    /// @notice Get the holder address by index
    function getHolderByIndex(DepositsStorage storage self, uint256 index) external view returns (address) {
        require(index < self.holders.length(), "PL:INVALID_INDEX");
        return self.holders.at(index);
    }

    /*
     * Deposit helpers
     */

    /// @notice Add a deposit for a holder
    /// @dev Add the holder to holders AddressSet, then push deposit to lockedDeposits array
    function addDeposit(DepositsStorage storage self, address holder, uint256 amount, uint256 unlockTime) external {
        require(holder != address(0), "PL:INVALID_HOLDER");
        require(amount > 0, "PL:ZERO_AMOUNT");
        require(unlockTime > block.timestamp, "PL:WRONG_UNLOCK_TIME");

        self.holders.add(holder);

        // Add the deposit to the lockedDeposits mapping
        self.lockedDeposits[holder].push(DepositInstance({
            amount: amount,
            unlockTime: unlockTime
        }));
    }

    /// @notice Cleanup expired deposit info
    /// @dev Should be extended to cleanup also holders
    function cleanupDepositsStorage(DepositsStorage storage self, address holder) public {
        DepositInstance[] storage depositInstances = self.lockedDeposits[holder];

        // Iterate in reverse to safely remove elements while modifying the array
        for (int256 j = int256(depositInstances.length) - 1; j >= 0; j--) {
            if (depositInstances[uint256(j)].unlockTime < block.timestamp) {
                // Remove the expired DepositInstance
                depositInstances[uint256(j)] = depositInstances[depositInstances.length - 1];
                depositInstances.pop();
            }
        }
    }

    /// @notice Get locked deposit amount for a specific holder
    function lockedDepositsAmount(DepositsStorage storage self, address holder) public view returns (uint256) {
        require(self.holders.contains(holder), "PL:INVALID_HOLDER");

        uint256 lockedAmount;

        for (uint256 i = 0; i < self.lockedDeposits[holder].length; i++) {
            if (self.lockedDeposits[holder][i].unlockTime > block.timestamp) {
                lockedAmount += self.lockedDeposits[holder][i].amount;
            }
        }

        return lockedAmount;
    }
}