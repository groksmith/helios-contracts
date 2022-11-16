// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IPoolFactory {

    event PoolFactoryAdminSet(address indexed poolFactoryAdmin, bool allowed);

    /**
        @dev   Emits an event indicating a Pool was created.
        @param pool             The address of the Pool.
        @param name             The name of the Pool FDTs.
        @param symbol           The symbol of the Pool FDTs.
     */
    event PoolCreated(address indexed poolDelegate, address indexed pool, string name, string symbol);

    /**
        @dev The current HeliosGlobals instance.
     */
    function globals() external view returns (address);

    /**
        @param  index An index of a Pool.
        @return The address of the Pool at `index`.
     */
    function pools(uint256 index) external view returns (address);

    /**
        @param  pool The address of a Pool.
        @return Whether the contract at `address` is a Pool.
     */
    function isPool(address pool) external view returns (bool);

    /**
        @param  poolFactoryAdmin The address of a PoolFactoryAdmin.
        @return Whether the `poolFactoryAdmin` has permission to do certain operations in case of disaster management
     */
    function poolFactoryAdmins(address poolFactoryAdmin) external view returns (bool);

    /**
        @dev   Sets HeliosGlobals instance.
        @dev   Only the Governor can call this function.
        @param newGlobals The address of new MapleGlobals.
     */
    function setGlobals(address newGlobals) external;

    /**
        @dev    Instantiates a Pool.
        @dev    It emits a `PoolCreated` event.
        @return poolAddress    The address of the instantiated Pool.
     */
    function createPool(
        uint256 lockupPeriod,
        uint256 apy,
        uint256 maxInvestmentSize,
        uint256 minInvestmentSize) external returns (address poolAddress);

    /**
        @dev Triggers paused state.
        @dev Halts functionality for certain functions.
        @dev Only the Governor or a PoolFactory Admin can call this function.
     */
    function pause() external;

    /**
        @dev Triggers unpaused state.
        @dev Restores functionality for certain functions.
        @dev Only the Governor or a PoolFactory Admin can call this function.
     */
    function unpause() external;
}
