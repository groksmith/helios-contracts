// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {PoolFactoryLibrary} from "../library/PoolFactoryLibrary.sol";
import {BlendedPoolFactoryLibrary} from "../library/BlendedPoolFactoryLibrary.sol";

import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {PoolErrors} from "./base/PoolErrors.sol";

/// @title Factory for Pool creation
/// @author Tigran Arakelyan
contract PoolFactory is IPoolFactory, ReentrancyGuard, PoolErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    IHeliosGlobals public immutable override globals; // A HeliosGlobals instance

    address public blendedPool; // Address of Blended Pool
    EnumerableSet.AddressSet private poolSet; // EnumerableSet of pools

    mapping(string => address) public pools; // Map to reference Pools corresponding to their respective indices.

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
    /// @param _tokenName token name
    /// @param _tokenSymbol token symbol
    function createPool(
        string calldata _poolId,
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount,
        uint256 _investmentPoolSize,
        string memory _tokenName,
        string memory _tokenSymbol)
    external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address poolAddress) {
        if (pools[_poolId] != address(0)) revert PoolIdAlreadyExists();

        poolAddress = PoolFactoryLibrary.createPool(
            _asset,
            _lockupPeriod,
            _minInvestmentAmount,
            _investmentPoolSize,
            _tokenName,
            _tokenSymbol);

        pools[_poolId] = poolAddress;
        poolSet.add(poolAddress);

        emit PoolCreated(_poolId, _asset, poolAddress, msg.sender);
    }

    /// @notice Instantiates a Blended Pool
    /// @param _asset address of asset of pool
    /// @param _lockupPeriod locking time for deposit's withdrawal
    /// @param _minInvestmentAmount minimal amount of asset needed to deposit
    /// @param _tokenName token name
    /// @param _tokenSymbol token symbol
    function createBlendedPool(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _minInvestmentAmount,
        string memory _tokenName,
        string memory _tokenSymbol)
    external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address blendedPoolAddress) {
        if (blendedPool != address(0)) revert BlendedPoolAlreadyCreated();

        blendedPoolAddress = BlendedPoolFactoryLibrary.createBlendedPool(
            _asset,
            _lockupPeriod,
            _minInvestmentAmount,
            _tokenName,
            _tokenSymbol
        );

        blendedPool = blendedPoolAddress;

        emit BlendedPoolCreated(_asset, blendedPoolAddress, msg.sender);
    }

    /// @notice Whitelist pools created here
    /// @param _pool address of pool to check
    function isValidPool(address _pool) external override view returns (bool) {
        return poolSet.contains(_pool);
    }

    /// @notice Return blended pool address
    function getBlendedPool() external override view returns (address) {
        return blendedPool;
    }

    /// @notice Checks that `msg.sender` is the Admin
    modifier onlyAdmin() {
        if (!globals.isAdmin(msg.sender)) revert NotAdmin();
        _;
    }

    /// @notice Checks that the protocol is not in a paused state
    modifier whenProtocolNotPaused() {
        if (globals.protocolPaused()) revert Paused();
        _;
    }
}
