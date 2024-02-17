// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library PoolLibrary {
    using EnumerableSet for EnumerableSet.AddressSet;

    enum State {
        Initialized,
        Finalized,
        Deactivated
    }

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 duration;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
        uint256 withdrawThreshold;
    }

    struct DepositInstance {
        uint256 amount;
        uint256 unlockTime;
    }

    struct DepositsStorage {
        EnumerableSet.AddressSet holders;

        mapping(address => DepositInstance[]) lockedDeposits;
    }

    /*
    * Holders helpers
    */

    // Get the count of holders
    function getHoldersCount(DepositsStorage storage self) external view returns (uint256) {
        return self.holders.length();
    }

    // Get the count of holders
    function holderExists(DepositsStorage storage self, address holder) external view returns (bool) {
        return self.holders.contains(holder);
    }

    // Get the holder address by index
    function getHolderByIndex(DepositsStorage storage self, uint256 index) external view returns (address) {
        require(index < self.holders.length(), "PL:INVALID_INDEX");
        return self.holders.at(index);
    }

    /*
     * Deposit helpers
     */

    // Add a deposit for a holder
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

    // Get locked deposit amount for a specific holder
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