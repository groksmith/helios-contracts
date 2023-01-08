// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

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

    function transferByCustodianChecks(address from, address to, uint256 amount) internal pure {
        require(to == from, "P:INVALID_RECEIVER");
        require(amount != uint256(0), "P:INVALID_AMT");
    }

    function increaseCustodyAllowanceChecks(address custodian, uint256 amount, uint256 newTotalAllowance, uint256 fdtBal) internal pure {
        require(custodian != address(0), "P:INVALID_CUSTODIAN");
        require(amount != uint256(0), "P:INVALID_AMT");
        require(newTotalAllowance <= fdtBal, "P:INSUF_BALANCE");
    }
}
