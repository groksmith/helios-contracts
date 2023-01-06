// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.1;

library SafeMathUint {
    function toInt256Safe(uint256 a) internal pure returns (int256 b) {
        b = int256(a);
        require(b >= 0, "SMU:OOB");
    }
}