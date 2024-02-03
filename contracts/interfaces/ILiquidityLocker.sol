// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILiquidityLocker {
    function transfer(address dst, uint256 amount) external returns (bool);

    function totalBalance() external view returns (uint256);

    function liquidityAsset() external view returns (IERC20);
}
