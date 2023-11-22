// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Pool.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../interfaces/IPoolFactory.sol";

// PoolFactory instantiates Pools
contract PoolFactory is IPoolFactory, Pausable, ReentrancyGuard {
    IHeliosGlobals public override globals; // A HeliosGlobals instance

    mapping(string => address) public pools; // Map to reference Pools corresponding to their respective indices.
    mapping(address => bool) public isPool; // True only if a Pool was instantiated by this factory.
    mapping(address => bool) public poolFactoryAdmins; // The PoolFactory Admin addresses that have permission to do certain operations in case of disaster management.

    event PoolFactoryAdminSet(address indexed poolFactoryAdmin, bool allowed);

    event PoolCreated(
        string poolId,
        address liquidityAsset,
        address indexed pool,
        address indexed delegate
    );

    constructor(address _globals) {
        globals = IHeliosGlobals(_globals);
    }

    // Sets HeliosGlobals instance. Only the Governor can call this function
    function setGlobals(address newGlobals) external {
        _isValidGovernor();
        require(newGlobals != address(0), "PF:ZERO_NEW_GLOBALS");
        globals = IHeliosGlobals(newGlobals);
    }

    // Instantiates a Pool
    function createPool(
        string calldata poolId,
        address liquidityAsset,
        address llFactory,
        uint256 lockupPeriod,
        uint256 apy,
        uint256 duration,
        uint256 investmentPoolSize,
        uint256 minInvestmentAmount
    ) external whenNotPaused nonReentrant returns (address poolAddress) {
        _whenProtocolNotPaused();

        IHeliosGlobals _globals = globals;
        require(_globals.isValidPoolDelegate(msg.sender), "PF:NOT_DELEGATE");

        _isMappingKeyValid(poolId);

        Pool pool = new Pool(
            msg.sender,
            liquidityAsset,
            llFactory,
            lockupPeriod,
            apy,
            duration,
            investmentPoolSize,
            minInvestmentAmount
        );

        poolAddress = address(pool);
        pools[poolId] = poolAddress;
        isPool[poolAddress] = true;

        emit PoolCreated(poolId, liquidityAsset, poolAddress, msg.sender);
    }

    // Sets a PoolFactory Admin. Only the Governor can call this function
    function setPoolFactoryAdmin(
        address poolFactoryAdmin,
        bool allowed
    ) external {
        _isValidGovernor();
        poolFactoryAdmins[poolFactoryAdmin] = allowed;
        emit PoolFactoryAdminSet(poolFactoryAdmin, allowed);
    }

    // Triggers paused state. Halts functionality for certain functions. Only the Governor or a PoolFactory Admin can call this function
    function pause() external {
        _isValidGovernorOrPoolFactoryAdmin();
        super._pause();
    }

    // Triggers unpaused state. Restores functionality for certain functions. Only the Governor or a PoolFactory Admin can call this function
    function unpause() external {
        _isValidGovernorOrPoolFactoryAdmin();
        super._unpause();
    }

    // Checks that `msg.sender` is the Governor
    function _isValidGovernor() internal view {
        require(msg.sender == globals.governor(), "PF:NOT_GOV");
    }

    // Checks that `msg.sender` is the Governor or a PoolFactory Admin
    function _isValidGovernorOrPoolFactoryAdmin() internal view {
        require(
            msg.sender == globals.governor() || poolFactoryAdmins[msg.sender],
            "PF:NOT_GOV_OR_ADM"
        );
    }

    // Checks that the protocol is not in a paused state
    function _whenProtocolNotPaused() internal view {
        require(!globals.protocolPaused(), "PF:PROTO_PAUSED");
    }

    // Checks that the mapping key is valid (unique)
    function _isMappingKeyValid(string calldata key) internal view {
        require(pools[key] == address(0), "PF:POOL_ID_ALREADY_EXISTS");
    }
}
