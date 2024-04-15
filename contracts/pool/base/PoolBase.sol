// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IPoolFactory} from "../../interfaces/IPoolFactory.sol";
import {PoolErrors} from "./PoolErrors.sol";

/// @title Base Pool contract
/// @author Tigran Arakelyan
/// @dev Should be inherited
abstract contract PoolBase is ERC20, ReentrancyGuard, PoolErrors {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset; // The asset deposited by Lenders into the Pool
    IPoolFactory public immutable poolFactory; // The Pool factory that deployed this Pool

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 minInvestmentAmount;
        uint256 investmentPoolSize;
    }

    PoolInfo public poolInfo;
    uint256 public totalInvested;

    constructor(address _asset, string memory _tokenName, string memory _tokenSymbol)
    ERC20(_tokenName, _tokenSymbol) {
        poolFactory = IPoolFactory(msg.sender);

        if (!poolFactory.globals().isValidAsset(_asset)) revert InvalidLiquidityAsset();

        asset = IERC20(_asset);
    }

    /// @notice Get the amount of assets in the pool
    function totalBalance() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @notice Get asset's decimals
    function decimals() public view override returns (uint8) {
        return ERC20(address(asset)).decimals();
    }

    /// @notice Get pool general info
    function getPoolInfo() public view returns (PoolInfo memory) {
        return poolInfo;
    }

    /*
    Modifiers
    */

    /// @notice Checks that value is not zero
    modifier notZero(uint256 _value) {
        if (_value == 0) revert InvalidValue();
        _;
    }

    /// @notice Checks that the protocol is not in a paused state
    modifier whenProtocolNotPaused() {
        if (poolFactory.globals().protocolPaused()) revert Paused();
        _;
    }

    /// @notice Checks that the admin call
    modifier onlyAdmin() {
        if (!poolFactory.globals().isAdmin(msg.sender)) revert NotAdmin();
        _;
    }
}