// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library PoolLib {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 10 ** 18;

    event DepositDateUpdated(address indexed liquidityProvider, uint256 depositDate);

    function updateDepositDate(mapping(address => uint256) storage depositDate, uint256 balance, uint256 amt, address account) internal {
        uint256 prevDate = depositDate[account];

        uint256 newDate = (balance + amt) > 0
            ? prevDate.add(block.timestamp.sub(prevDate).mul(amt).div(balance + amt))
            : prevDate;

        depositDate[account] = newDate;
        emit DepositDateUpdated(account, newDate);
    }
}
