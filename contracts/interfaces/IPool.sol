// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IPool {
    /**
        Initialized = The Pool has been initialized and is ready for liquidity.
        Finalized   = The Pool has been sufficiently sourced wth liquidity.
        Deactivated = The Pool has been emptied and deactivated.
     */
    enum State {Initialized, Finalized, Deactivated}

    /**
        @dev   Emits an event indicating a that the state of the Pool has changed.
        @param state The new state of the Pool.
     */
    event PoolStateChanged(State state);

    /**
        @dev   Emits an event indicating a that a PoolAdmin was set.
        @param poolAdmin The address of a PoolAdmin.
        @param allowed   Whether `poolAdmin` is an admin of the Pool.
     */
    event PoolAdminSet(address indexed poolAdmin, bool allowed);

    /**
        @dev The state of the Pool.
     */
    function poolState() external view returns (State);

    /**
        @dev The period of time from an account's deposit date during which they cannot withdraw any funds.
     */
    function lockupPeriod() external view returns (uint256);

    /**
        @dev The apy of the Pool.
     */
    function apy() external view returns (uint256);

    /**
        @dev maxInvestmentSize for the Pool.
     */
    function maxInvestmentSize() external view returns (uint256);

    /**
        @dev minInvestmentSize for the Pool.
     */
    function minInvestmentSize() external view returns (uint256);

    /**
        @dev Whether the Pool is open to the public for LP deposits.
     */
    function openToPublic() external view returns (bool);

    /**
        @param  poolAdmin The address of a PoolAdmin.
        @return Whether `poolAdmin` has permission to do certain operations in case of disaster management.
     */
    function poolAdmins(address poolAdmin) external view returns (bool);

    /**
        @dev The Pool Delegate address, maintains full authority over the Pool.
     */
    function poolDelegate() external view returns (address);

    /**
        @dev   Sets a Pool Admin.
        @dev   Only the Pool Delegate can call this function.
        @dev   It emits a `PoolAdminSet` event.
        @param poolAdmin An address being allowed or disallowed as a Pool Admin.
        @param allowed   Whether `poolAdmin` is an admin of the Pool.
     */
    function setPoolAdmin(address poolAdmin, bool allowed) external;
}
