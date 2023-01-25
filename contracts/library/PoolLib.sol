// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library PoolLib {
    using SafeMath for uint256;

    string public constant NAME = "Helios TKN Pool";
    string public constant SYMBOL = "HLS-P";

    event DepositDateUpdated(address indexed liquidityProvider, uint256 depositDate);

    function updateDepositDate(mapping(address => uint256) storage depositDate, uint256 balance, uint256 amount, address account) internal {
        uint256 prevDate = depositDate[account];

        uint256 newDate = (balance + amount) > 0
        ? prevDate.add(block.timestamp.sub(prevDate).mul(amount).div(balance + amount))
        : prevDate;

        depositDate[account] = newDate;
        emit DepositDateUpdated(account, newDate);
    }
}
