// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// PoolLib is a library of utility functions used by Pool.
library PoolLib {
    using SafeMath for uint256;

    string public constant NAME = "Helios TKN Pool";
    string public constant SYMBOL = "HLS-P";

    event DepositDateUpdated(address indexed liquidityProvider, uint256 depositDate);

    // Updates the effective deposit date based on how much new capital has been added.
    // If more capital is added, the deposit date moves closer to the current timestamp.
    function updateDepositDate(mapping(address => uint256) storage depositDate, uint256 balance, uint256 amount, address account) internal {
        uint256 prevDate = depositDate[account];

        uint256 newDate = (balance + amount) > 0
        ? prevDate.add(block.timestamp.sub(prevDate).mul(amount).div(balance + amount))
        : prevDate;

        depositDate[account] = newDate;
        emit DepositDateUpdated(account, newDate);
    }
}
