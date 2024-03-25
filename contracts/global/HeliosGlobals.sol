// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";

/// @title HeliosGlobals contract
/// @author Tigran Arakelyan
/// @notice Maintains a central source of parameters and allowLists for the Helios protocol.
contract HeliosGlobals is AccessControl, IHeliosGlobals {
    bool public override protocolPaused; // Switch to pause the functionality of the entire protocol.
    address public override poolFactory; // Mapping of valid Pool Factories
    mapping(address => bool) public override isValidAsset; // Mapping of valid Assets

    event ProtocolPaused(bool pause);
    event Initialized();
    event PoolFactorySet(address indexed poolFactory);
    event AssetSet(address asset, uint256 decimals, string symbol, bool valid);

    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        emit Initialized();
    }

    /// @notice Check if account is admin of Helios protocol
    function isAdmin(address _account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _account);
    }

    /// @notice Sets the paused/unpaused state of the protocol. Only the Admin can call this function
    function setProtocolPause(bool _pause) external onlyAdmin {
        protocolPaused = _pause;
        emit ProtocolPaused(_pause);
    }

    /// @notice Sets the valid PoolFactory instance. Only the Admin can call this function
    function setPoolFactory(address _poolFactory) external onlyAdmin {
        require(_poolFactory != address(0), "HG:ZERO_POOL_FACTORY");

        poolFactory = _poolFactory;
        emit PoolFactorySet(_poolFactory);
    }

    /// @notice Sets the validity of an asset for Pools. Only the Admin can call this function
    function setAsset(address _asset, bool _valid) external onlyAdmin {
        require(_asset != address(0), "HG:ZERO_ASSET");
        isValidAsset[_asset] = _valid;
        emit AssetSet(_asset, IERC20Metadata(_asset).decimals(), IERC20Metadata(_asset).symbol(), _valid);
    }

    /// @notice Restricted to members of the admin role.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "HG:NOT_ADMIN");
        _;
    }
}
