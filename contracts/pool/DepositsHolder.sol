// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";

// TODO: Tigran. I hate doing that, need something better
contract DepositsHolder {
    address private immutable pool;
    address[] private holders;
    mapping(address => PoolLibrary.DepositInstance[]) private userDeposits;

    constructor(address _pool) {
        require(_pool != address(0), "DH:INVALID_POOL");
        pool = _pool;
    }

    // Add a deposit for a holder
    function addDeposit(
        address holder,
        IERC20 token,
        uint256 amount,
        uint256 unlockTime
    ) external onlyPool {
        bool holderExists = isHolderExists(holder);

        // If the holder doesn't exist, add them to the list
        if (!holderExists) {
            holders.push(holder);
        }

        // Add the deposit to the userDeposits mapping
        userDeposits[holder].push(PoolLibrary.DepositInstance({
            token: token,
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

    // Get the count of holders
    function getHoldersCount() external view returns (uint256) {
        return holders.length;
    }

    // Get the holder address by index
    function getHolderByIndex(uint256 index) external view returns (address) {
        require(index < holders.length, "DH:INVALID_INDEX");
        return holders[index];
    }

    // Get deposits for a specific holder
    function getDepositsByHolder(address holder) external view returns (PoolLibrary.DepositInstance[] memory) {
        require(isHolderExists(holder), "DH:INVALID_HOLDER");
        return userDeposits[holder];
    }

    // Check if the holder already exists in the list
    function isHolderExists(address holder) internal view returns (bool) {
        bool holderExists = false;
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == holder) {
                holderExists = true;
                break;
            }
        }
        return holderExists;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "DH:NOT_POOL");
        _;
    }
}