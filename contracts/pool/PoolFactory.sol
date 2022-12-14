// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Pool.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../interfaces/IPoolFactory.sol";

contract PoolFactory is IPoolFactory, Pausable, ReentrancyGuard {
    IHeliosGlobals public override globals;

    mapping(string => address)  public pools;               // Map to reference Pools corresponding to their respective indices.
    mapping(address => bool)    public isPool;              // True only if a Pool was instantiated by this factory.
    mapping(address => bool)    public poolFactoryAdmins;   // The PoolFactory Admin addresses that have permission to do certain operations in case of disaster management.

    event PoolFactoryAdminSet(address indexed poolFactoryAdmin, bool allowed);

    event PoolCreated(string poolId, address liquidityAsset, address indexed pool, address indexed delegate);

    constructor(address _globals) {
        globals = IHeliosGlobals(_globals);
    }

    function setGlobals(address newGlobals) external {
        _isValidGovernor();
        require(newGlobals != address(0), "PF:ZERO_NEW_GLOBALS");
        globals = IHeliosGlobals(newGlobals);
    }

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
        {
            IHeliosGlobals _globals = globals;
            require(_globals.isValidPoolDelegate(msg.sender), "PF:NOT_DELEGATE");
        }

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

    function setPoolFactoryAdmin(address poolFactoryAdmin, bool allowed) external {
        _isValidGovernor();
        poolFactoryAdmins[poolFactoryAdmin] = allowed;
        emit PoolFactoryAdminSet(poolFactoryAdmin, allowed);
    }

    function pause() external {
        _isValidGovernorOrPoolFactoryAdmin();
        super._pause();
    }

    function unpause() external {
        _isValidGovernorOrPoolFactoryAdmin();
        super._unpause();
    }

    function _isValidGovernor() internal view {
        require(msg.sender == globals.governor(), "PF:NOT_GOV");
    }

    function _isValidGovernorOrPoolFactoryAdmin() internal view {
        require(msg.sender == globals.governor() || poolFactoryAdmins[msg.sender], "PF:NOT_GOV_OR_ADM");
    }

    function _whenProtocolNotPaused() internal view {
        require(!globals.protocolPaused(), "PF:PROTO_PAUSED");
    }

    function _isMappingKeyValid(string calldata key) internal view {
        require(pools[key] == address(0), "PF:POOL_ID_ALREADY_EXISTS");
    }
}
