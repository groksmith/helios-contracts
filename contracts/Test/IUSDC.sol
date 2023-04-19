// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IUSDC is IERC20, IERC20Metadata {
    function getOwner() external view returns (address);

    function issue(uint256) external;
}