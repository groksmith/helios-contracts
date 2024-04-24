// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {HeliosGlobalsErrors} from "./HeliosGlobalsErrors.sol";

/// @title HeliosGlobals contract
/// @author Tigran Arakelyan
/// @notice Maintains a central source of parameters and allowLists for the Helios protocol.
contract HeliosGlobals is AccessControl, IHeliosGlobals, HeliosGlobalsErrors {
    address private immutable multiSigAdmin; // MultiSig admin contract address
    bool public override protocolPaused; // Switch to pause the functionality of the entire protocol.
    address public override poolFactory; // Mapping of valid Pool Factories
    mapping(address => bool) public override isValidAsset; // Mapping of valid Assets

    event MultiSigAdminSet(address indexed account);
    event ProtocolPaused(bool pause);
    event Initialized();
    event PoolFactorySet(address indexed poolFactory);
    event AssetSet(address asset, uint256 decimals, string symbol, bool valid);

    bytes32 public constant MULTI_SIG_ADMIN = keccak256("MULTI_SIG_ADMIN");

    constructor(address _admin, address _multiSigAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        multiSigAdmin = _multiSigAdmin;
        emit Initialized();
    }

    /// @notice Check if account is admin of Helios protocol
    function isAdmin(address _account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _account);
    }

    /// @notice Check if account is MultiSigAdmin of Helios protocol
    function isMultiSigAdmin(address _account) public view returns (bool) {
        return multiSigAdmin == _account;
    }

    /// @notice Sets the paused/unpaused state of the protocol. Only the Admin can call this function
    function setProtocolPause(bool _pause) external onlyAdmin {
        protocolPaused = _pause;
        emit ProtocolPaused(_pause);
    }

    /// @notice Sets the valid PoolFactory instance. Only the Admin can call this function
    function setPoolFactory(address _poolFactory) external onlyAdmin {
        if (_poolFactory == address(0)) revert ZeroPoolFactory();

        poolFactory = _poolFactory;
        emit PoolFactorySet(_poolFactory);
    }

    /// @notice Sets the validity of an asset for Pools. Only the Admin can call this function
    function setAsset(address _asset, bool _valid) external onlyAdmin {
        if (_asset == address(0)) revert ZeroAsset();
        isValidAsset[_asset] = _valid;
        emit AssetSet(_asset, IERC20Metadata(_asset).decimals(), IERC20Metadata(_asset).symbol(), _valid);
    }

    /// @notice Restricted to members of the admin role.
    modifier onlyAdmin() {
        if (!isAdmin(msg.sender)) revert NotAdmin();
        _;
    }
}
