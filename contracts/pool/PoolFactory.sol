// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {PoolFactoryLibrary} from "../library/PoolFactoryLibrary.sol";
import {BlendedPoolFactoryLibrary} from "../library/BlendedPoolFactoryLibrary.sol";

import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";

/// @title Factory for Pool creation
/// @author Tigran Arakelyan
contract PoolFactory is IPoolFactory, ReentrancyGuard {
    IHeliosGlobals public override globals; // A HeliosGlobals instance

    address public blendedPool; // Address of Blended Pool
    mapping(string => address) public pools; // Map to reference Pools corresponding to their respective indices.
    mapping(address => bool) public isPool; // True only if a Pool was instantiated by this factory.

    event PoolCreated(string poolId, address asset, address indexed pool, address indexed delegate);
    event BlendedPoolCreated(address asset, address indexed pool, address indexed delegate);

    constructor(address _globals) {
        globals = IHeliosGlobals(_globals);
    }

    /// @notice Instantiates a Pool
    function createPool(
        string calldata poolId,
        address asset,
        uint256 lockupPeriod,
        uint256 duration,
        uint256 investmentPoolSize,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address poolAddress) {
        _isMappingKeyValid(poolId);

        poolAddress = PoolFactoryLibrary.createPool(
            poolId,
            asset,
            lockupPeriod,
            duration,
            investmentPoolSize,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod);

        pools[poolId] = poolAddress;
        isPool[poolAddress] = true;

        emit PoolCreated(poolId, asset, poolAddress, msg.sender);
    }

    /// @notice Instantiates a Blended Pool
    function createBlendedPool(
        address asset,
        uint256 lockupPeriod,
        uint256 duration,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address blendedPoolAddress) {

        require(blendedPool == address(0), "PF:BLENDED_POOL_ALREADY_CREATED");

        blendedPoolAddress = BlendedPoolFactoryLibrary.createBlendedPool(
            asset,
            lockupPeriod,
            duration,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );

        blendedPool = blendedPoolAddress;

        emit BlendedPoolCreated(asset, blendedPoolAddress, msg.sender);
    }

    /// @notice Checks that the mapping key is valid (unique)
    /// @dev Only for external systems compatibility
    function _isMappingKeyValid(string memory _key) internal view {
        require(pools[_key] == address(0), "PF:POOL_ID_ALREADY_EXISTS");
    }

    /// @notice Whitelist pools created here
    function isValidPool(address _pool) external override view returns (bool) {
        return isPool[_pool];
    }

    /// @notice Return blended pool address
    function getBlendedPool() external override view returns (address) {
        return blendedPool;
    }

    /*
    Modifiers
    */

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
