// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {PoolFactoryLibrary} from "../library/PoolFactoryLibrary.sol";
import {BlendedPoolFactoryLibrary} from "../library/BlendedPoolFactoryLibrary.sol";

import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";

/// @title Factory for Pool creation
/// @author Tigran Arakelyan
contract PoolFactory is IPoolFactory, ReentrancyGuard {
    IHeliosGlobals public immutable override globals; // A HeliosGlobals instance

    address public blendedPool; // Address of Blended Pool
    mapping(string => address) public pools; // Map to reference Pools corresponding to their respective indices.
    mapping(address => bool) public isPool; // True only if a Pool was instantiated by this factory.

    event PoolCreated(string poolId, address asset, address indexed pool, address indexed delegate);
    event BlendedPoolCreated(address asset, address indexed pool, address indexed delegate);

    constructor(address _globals) {
        globals = IHeliosGlobals(_globals);
    }

    /// @notice Instantiates a Pool
    /// @param _poolId string for pool identification (for external systems)
    /// @param _asset address of asset of pool
    /// @param _lockupPeriod locking time for deposit's withdrawal
    /// @param _minInvestmentAmount minimal amount of asset needed to deposit
    /// @param _investmentPoolSize pool max capacity for deposits
    function createPool(
        string calldata _poolId,
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount,
        uint256 _investmentPoolSize
    ) external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address poolAddress) {
        _isMappingKeyValid(_poolId);

        poolAddress = PoolFactoryLibrary.createPool(
            _asset,
            _lockupPeriod,
            _minInvestmentAmount,
            _investmentPoolSize);

        pools[_poolId] = poolAddress;
        isPool[poolAddress] = true;

        emit PoolCreated(_poolId, _asset, poolAddress, msg.sender);
    }

    /// @notice Instantiates a Blended Pool
    /// @param _asset address of asset of pool
    /// @param _lockupPeriod locking time for deposit's withdrawal
    /// @param _minInvestmentAmount minimal amount of asset needed to deposit
    function createBlendedPool(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount
    ) external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address blendedPoolAddress) {

        require(blendedPool == address(0), "PF:BLENDED_POOL_ALREADY_CREATED");

        blendedPoolAddress = BlendedPoolFactoryLibrary.createBlendedPool(
            _asset,
            _lockupPeriod,
            _minInvestmentAmount
        );

        require(blendedPoolAddress != address(0), "PF:BLENDED_POOL_NOT_CREATED");
        blendedPool = blendedPoolAddress;

        emit BlendedPoolCreated(_asset, blendedPoolAddress, msg.sender);
    }

    /// @notice Checks that the mapping key is valid (unique)
    /// @dev Only for external systems compatibility
    function _isMappingKeyValid(string calldata _key) internal view {
        require(pools[_key] == address(0), "PF:POOL_ID_ALREADY_EXISTS");
    }

    /// @notice Whitelist pools created here
    /// @param _pool address of pool to check
    function isValidPool(address _pool) external override view returns (bool) {
        return isPool[_pool];
    }

    /// @notice Return blended pool address
    function getBlendedPool() external override view returns (address) {
        return blendedPool;
    }

    /// @notice Checks that `msg.sender` is the Admin
    modifier onlyAdmin() {
        require(globals.isAdmin(msg.sender), "PF:NOT_ADMIN");
        _;
    }

    /// @notice Checks that the protocol is not in a paused state
    modifier whenProtocolNotPaused() {
        require(!globals.protocolPaused(), "P:PROTO_PAUSED");
        _;
    }
}
