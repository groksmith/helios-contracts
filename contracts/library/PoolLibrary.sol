// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

        mapping(address => DepositInstance[]) userDeposits;
    }

    /*
    * Holders helpers
    */

    // Get the count of holders
    function getHoldersCount(DepositsStorage storage self) external view returns (uint256) {
        return self.holders.length();
    }

    // Get the holder address by index
    function getHolderByIndex(DepositsStorage storage self, uint256 index) external view returns (address) {
        require(index < self.holders.length(), "DH:INVALID_INDEX");
        return self.holders.at(index);
    }

    function getHolders(DepositsStorage storage self) external view returns (address[] memory) {
        return self.holders.values();
    }

    /*
     * Deposit helpers
     */

    // Add a deposit for a holder
    function addDeposit(DepositsStorage storage self, address holder, uint256 amount, uint256 unlockTime) external {
        self.holders.add(holder);

        // Add the deposit to the userDeposits mapping
        self.userDeposits[holder].push(DepositInstance({
            amount: amount,
            unlockTime: unlockTime
        }));
    }

    // Delete a deposit for a holder. Warning: deposits order will be changed!
    function updateDeposits(DepositsStorage storage self, address holder, uint256 amount) external {
        require(self.holders.contains(holder), "DH:INVALID_HOLDER");

        uint256 cachedAmount = amount;
        for (uint256 i = 0; i < self.userDeposits[holder].length; i++) {
            if (self.userDeposits[holder][i].unlockTime >= block.timestamp) {
                if (self.userDeposits[holder][i].amount >= cachedAmount) {
                    cachedAmount -= self.userDeposits[holder][i].amount;
                    self.userDeposits[holder][i].amount = 0;
                } else {
                    self.userDeposits[holder][i].amount -= cachedAmount;
                    cachedAmount = 0;
                }
            }
        }
    }

    // Get deposits for a specific holder
    function allowedToWithdraw(DepositsStorage storage self, address holder) external view returns (uint256) {
        require(self.holders.contains(holder), "DH:INVALID_HOLDER");

        uint256 unlockedDepositAmount;

        for (uint256 i = 0; i < self.userDeposits[holder].length; i++) {
            if (self.userDeposits[holder][i].unlockTime >= block.timestamp) {
                unlockedDepositAmount += self.userDeposits[holder][i].amount;
            }
        }

        return unlockedDepositAmount;
    }
}