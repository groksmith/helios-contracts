// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";

contract DepositsHolder {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private immutable pool;

    EnumerableSet.AddressSet private holders;

    mapping(address => PoolLibrary.DepositInstance[]) private userDeposits;

    constructor(address _pool) {
        require(_pool != address(0), "DH:INVALID_POOL");
        pool = _pool;
    }

    /*
    * Holders helpers
    */

    // Get the count of holders
    function getHoldersCount() external view returns (uint256) {
        return holders.length();
    }

    // Get the holder address by index
    function getHolderByIndex(uint256 index) external view returns (address) {
        require(index < holders.length(), "DH:INVALID_INDEX");
        return holders.at(index);
    }

    function getHolders() external view returns (address[] memory) {
        return holders.values();
    }

    /*
    * Deposit helpers
    */

    // Add a deposit for a holder
    function addDeposit(address holder, uint256 amount, uint256 unlockTime) external onlyPool {
        holders.add(holder);

        // Add the deposit to the userDeposits mapping
        userDeposits[holder].push(PoolLibrary.DepositInstance({
            amount: amount,
            unlockTime: unlockTime
        }));
    }

    // Delete a deposit for a holder. Warning: deposits order will be changed!
    function deleteDeposit(address holder, uint256 depositIndex) external onlyPool {
        require(depositIndex < userDeposits[holder].length, "DH:INVALID_INDEX");

        // Delete the deposit
        userDeposits[holder][depositIndex] = userDeposits[holder][userDeposits[holder].length - 1];
        userDeposits[holder].pop();
    }

    // Get deposits for a specific holder
    function getDepositsByHolder(address holder) external view returns (PoolLibrary.DepositInstance[] memory) {
        require(holders.contains(holder), "DH:INVALID_HOLDER");
        return userDeposits[holder];
    }

    /*
    Modifiers
    */

    modifier onlyPool() {
        require(msg.sender == pool, "DH:NOT_POOL");
        _;
    }
}