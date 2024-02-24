// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title PoolLibrary
/// @author Tigran Arakelyan
/// @notice Types and storage for holders and deposit information.
library PoolLibrary {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    uint256 internal constant PRECISION = 1e18;

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
    function getHoldersCount(DepositsStorage storage self) internal view returns (uint256) {
        return self.holders.length();
    }

    /// @notice Return true if holder exists
    function holderExists(DepositsStorage storage self, address _holder) internal view returns (bool) {
        return self.holders.contains(_holder);
    }

    /// @notice Get the holder address by index
    function getHolderByIndex(DepositsStorage storage self, uint256 _index) internal view returns (address) {
        require(_index < self.holders.length(), "PL:INVALID_INDEX");
        return self.holders.at(_index);
    }

    /*
     * Deposit helpers
     */

    /// @notice Add a deposit for a holder
    /// @dev Add the holder to holders AddressSet, then push deposit to lockedDeposits array
    function addDeposit(DepositsStorage storage self, address _holder, uint256 _amount, uint256 _unlockTime) internal {
        require(_holder != address(0), "PL:INVALID_HOLDER");
        require(_amount > 0, "PL:ZERO_AMOUNT");
        require(_unlockTime > block.timestamp, "PL:WRONG_UNLOCK_TIME");

        self.holders.add(_holder);

        // Add the deposit to the lockedDeposits mapping
        self.lockedDeposits[_holder].push(DepositInstance({
            amount: _amount,
            unlockTime: _unlockTime
        }));
    }

    function previewChangeDepositOwnership(
        DepositsStorage storage self,
        address _holder,
        address _newHolder,
        uint256 _amount
    ) internal returns (uint256) {
        require(_holder != address(0), "PL:INVALID_HOLDER");
        require(_newHolder != address(0), "PL:INVALID_NEW_HOLDER");
        require(_amount > 0, "PL:ZERO_AMOUNT");

        uint256 totalMoved = 0;
        uint256 totalAmount = PoolLibrary.totalDepositsAmount(self, _holder);

        uint256 share = _amount.mulDiv(PRECISION, totalAmount);

        self.holders.add(_newHolder);

        if (share == 0) return totalMoved;

        uint256 count = self.lockedDeposits[_holder].length;
        for (uint256 i = 0; i < count; i++) {
            uint256 unlockTime = self.lockedDeposits[_holder][i].unlockTime;

            uint256 amountToMove = share.mulDiv(self.lockedDeposits[_holder][i].amount, PRECISION);
            totalMoved += amountToMove;

            if (amountToMove > 0)
            {
                // Add the deposit to the lockedDeposits mapping
                self.lockedDeposits[_newHolder].push(DepositInstance({
                    amount: amountToMove,
                    unlockTime: unlockTime
                }));

                self.lockedDeposits[_holder][i].amount -= amountToMove;
            }
        }

        return totalMoved;
    }

    /// @notice Get locked deposit amount for a specific holder
    function lockedDepositsAmount(DepositsStorage storage self, address _holder) internal view returns (uint256) {
        require(self.holders.contains(_holder), "PL:INVALID_HOLDER");

        uint256 lockedAmount = 0;

        uint256 count = self.lockedDeposits[_holder].length;
        for (uint256 i = 0; i < count; i++) {
            if (self.lockedDeposits[_holder][i].unlockTime > block.timestamp) {
                lockedAmount += self.lockedDeposits[_holder][i].amount;
            }
        }

        return lockedAmount;
    }
    /// @notice Get locked deposit amount for a specific holder
    function totalDepositsAmount(DepositsStorage storage self, address _holder) internal view returns (uint256) {
        require(self.holders.contains(_holder), "PL:INVALID_HOLDER");

        uint256 totalAmount = 0;

        uint256 count = self.lockedDeposits[_holder].length;
        for (uint256 i = 0; i < count; i++) {
            totalAmount += self.lockedDeposits[_holder][i].amount;
        }

        return totalAmount;
    }
}