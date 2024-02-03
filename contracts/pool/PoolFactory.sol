// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Pool} from "./Pool.sol";
import {BlendedPool} from "./BlendedPool.sol";
import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";

// PoolFactory instantiates Pools
contract PoolFactory is IPoolFactory, ReentrancyGuard {
    IHeliosGlobals public override globals; // A HeliosGlobals instance

    address public blendedPool; // Address of Blended Pool
    mapping(string => address) public pools; // Map to reference Pools corresponding to their respective indices.
    mapping(address => bool) public isPool; // True only if a Pool was instantiated by this factory.

    event PoolCreated(string poolId, address liquidityAsset, address indexed pool, address indexed delegate);
    event BlendedPoolCreated(address liquidityAsset, address indexed pool, address indexed delegate);

    constructor(address _globals) {
        globals = IHeliosGlobals(_globals);
    }

    // Sets HeliosGlobals instance. Only the Admin can call this function
    function setGlobals(address _newGlobals) external onlyAdmin {
        require(_newGlobals != address(0), "PF:ZERO_NEW_GLOBALS");
        globals = IHeliosGlobals(_newGlobals);
    }

    // Instantiates a Pool
    function createPool(
        string memory poolId,
        address liquidityAsset,
        address liquidityLockerFactory,
        uint256 lockupPeriod,
        uint256 apy,
        uint256 duration,
        uint256 investmentPoolSize,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address poolAddress) {
        _isMappingKeyValid(poolId);

        Pool pool = new Pool(
            liquidityAsset,
            liquidityLockerFactory,
            lockupPeriod,
            apy,
            duration,
            investmentPoolSize,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );

        poolAddress = address(pool);
        pools[poolId] = poolAddress;
        isPool[poolAddress] = true;

        emit PoolCreated(poolId, liquidityAsset, poolAddress, msg.sender);
    }

    // Instantiates a Pool
    function createBlendedPool(
        address liquidityAsset,
        address liquidityLockerFactory,
        uint256 lockupPeriod,
        uint256 apy,
        uint256 duration,
        uint256 minInvestmentAmount,
        uint256 withdrawThreshold,
        uint256 withdrawPeriod
    ) external virtual onlyAdmin whenProtocolNotPaused nonReentrant returns (address blendedPoolAddress) {

        require(blendedPool == address(0), "PF:BLENDED_POOL_ALREADY_CREATED");

        BlendedPool pool = new BlendedPool(
            liquidityAsset,
            liquidityLockerFactory,
            lockupPeriod,
            apy,
            duration,
            minInvestmentAmount,
            withdrawThreshold,
            withdrawPeriod
        );

        blendedPoolAddress = address(pool);
        blendedPool = blendedPoolAddress;

        emit BlendedPoolCreated(liquidityAsset, blendedPoolAddress, msg.sender);
    }

    // Checks that the mapping key is valid (unique)
    function _isMappingKeyValid(string memory _key) internal view {
        require(pools[_key] == address(0), "PF:POOL_ID_ALREADY_EXISTS");
    }

    function isValidPool(address _pool) external override view returns (bool) {
        return isPool[_pool];
    }

    function getBlendedPool() external override view returns (address) {
        return blendedPool;
    }

    /*
    Modifiers
    */

    // Checks that `msg.sender` is the Admin
    modifier onlyAdmin() {
        require(globals.isAdmin(msg.sender), "PF:NOT_ADMIN");
        _;
    }

    // Checks that the protocol is not in a paused state
    modifier whenProtocolNotPaused() {
        require(!globals.protocolPaused(), "P:PROTO_PAUSED");
        _;
    }
}
