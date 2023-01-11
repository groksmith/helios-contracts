// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library PoolLib {
    using SafeMath for uint256;

    string public constant NAME = "Helios TKN Pool";
    string public constant SYMBOL = "HLS-P";
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
        require(to == from, "P:INV_TO");
        require(amount != uint256(0), "P:INV_AMT");
    }

    function increaseCustodyAllowanceChecks(address custodian, uint256 amount, uint256 newTotalAllowance, uint256 fdtBal) internal pure {
        require(custodian != address(0), "P:INV_CUSTODIAN");
        require(amount != uint256(0), "P:INV_AMT");
        require(newTotalAllowance <= fdtBal, "P:INSUF_BAL");
    }
}
