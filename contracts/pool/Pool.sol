// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/IPoolFactory.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../library/PoolLib.sol";
import "./AbstractPool.sol";
import "./BlendedPool.sol";

import "hardhat/console.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool
    address public immutable poolDelegate; // The Pool Delegate address, maintains full authority over the Pool
    BlendedPool public blendedPool;

    uint256 public principalOut; // The sum of all outstanding principal on Loans.
    address public borrower; // Address of borrower for this Pool.

    enum State {
        Initialized,
        Finalized,
        Deactivated
    }
    State public poolState;

    event PoolStateChanged(State state);
    event PoolAdminSet(address indexed poolAdmin, bool allowed);
    event BorrowerSet(address indexed borrower);
    event Drawdown(
        address indexed borrower,
        uint256 amount,
        uint256 principalOut
    );
    event Payment(
        address indexed borrower,
        uint256 amount,
        uint256 principalOut
    );

    mapping(address => bool) public poolAdmins; // The Pool Admin addresses that have permission to do certain operations in case of disaster management

    constructor(
        address _poolDelegate,
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount
    ) AbstractPool(_liquidityAsset, _llFactory, PoolLib.NAME, PoolLib.SYMBOL) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_poolDelegate != address(0), "P:ZERO_POOL_DLG");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");
        poolInfo = PoolInfo(
            _lockupPeriod,
            _apy,
            _duration,
            _investmentPoolSize,
            _minInvestmentAmount
        );

        superFactory = msg.sender;
        poolDelegate = _poolDelegate;

        poolState = State.Initialized;

        require(
            _globals(superFactory).isValidLiquidityAsset(_liquidityAsset),
            "P:INVALID_LIQ_ASSET"
        );

        emit PoolStateChanged(poolState);
    }

    // Finalizes the Pool, enabling deposits. Only the Pool Delegate can call this function
    function finalize() external {
        _isValidDelegateAndProtocolNotPaused();
        _isValidState(State.Initialized);
        poolState = State.Finalized;
        emit PoolStateChanged(poolState);
    }

    // Triggers deactivation, permanently shutting down the Pool. Only the Pool Delegate can call this function
    function deactivate() external {
        _isValidDelegateAndProtocolNotPaused();
        _isValidState(State.Finalized);
        poolState = State.Deactivated;
        emit PoolStateChanged(poolState);
    }

    /// @notice Used to transfer the investor's rewards to him
    function claimReward() external override returns (bool) {
        uint256 callerRewards = rewards[msg.sender];
        require(callerRewards >= 0, "P:NOT_HOLDER");
        uint256 totalBalance = liquidityLocker.totalBalance();
        rewards[msg.sender] = 0;

        if (totalBalance < callerRewards) {
            uint256 amountMissing = callerRewards - totalBalance;

            if (blendedPool.totalLA() < amountMissing) {
                pendingRewards[msg.sender] += callerRewards;
                emit PendingReward(msg.sender, callerRewards);
                return false;
            }

            blendedPool.requestLiquidityAssets(amountMissing);
            _mint(address(blendedPool), amountMissing);

            require(
                _transferLiquidityLockerFunds(msg.sender, callerRewards),
                "P:ERROR_TRANSFERRING_REWARD"
            );

            emit RewardClaimed(msg.sender, callerRewards);
            return true;
        }

        require(
            _transferLiquidityLockerFunds(msg.sender, callerRewards),
            "P:ERROR_TRANSFERRING_REWARD"
        );

        emit RewardClaimed(msg.sender, callerRewards);
        return true;
    }

    function canWithdraw(uint256 amount) external view returns (bool) {
        _canWithdraw(msg.sender, amount);
        return true;
    }

    function withdrawableOf(address _holder) external view returns (uint256) {
        require(
            depositDate[_holder].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );

        return
            Math.min(
                liquidityAsset.balanceOf(address(liquidityLocker)),
                super.balanceOf(_holder)
            );
    }

    function totalDeposited() external view returns (uint256) {
        return totalMinted;
    }

    function drawdownAmount() external view returns (uint256) {
        return _drawdownAmount();
    }

    function drawdown(uint256 amount) external isBorrower nonReentrant {
        require(amount > 0, "P:INVALID_AMOUNT");
        require(amount <= _drawdownAmount(), "P:INSUFFICIENT_TOTAL_SUPPLY");

        principalOut = principalOut.add(amount);

        _transferLiquidityLockerFunds(msg.sender, amount);
        emit Drawdown(msg.sender, amount, principalOut);
    }

    function makePayment(
        uint256 principalClaim
    ) external isBorrower nonReentrant {
        uint256 interestClaim = 0;

        if (principalClaim <= principalOut) {
            principalOut = principalOut - principalClaim;
        } else {
            // Distribute `principalClaim` overflow as interest to LPs.
            interestClaim = principalClaim - principalOut;

            // Set `principalClaim` to `principalOut` so correct amount gets transferred.
            principalClaim = principalOut;

            // Set `principalOut` to zero to avoid subtraction overflow.
            principalOut = 0;
        }

        interestSum = interestSum.add(interestClaim);

        _transferLiquidityAssetFrom(
            msg.sender,
            address(liquidityLocker),
            principalClaim.add(interestClaim)
        );
        updateFundsReceived();

        emit Payment(msg.sender, principalClaim, interestSum);
    }

    function decimals() public view override returns (uint8) {
        return uint8(liquidityAssetDecimals);
    }

    //TODO to be deactivated
    function withdrawFunds() public override {
        _whenProtocolNotPaused();
        uint256 withdrawableFunds = _prepareWithdraw();

        if (withdrawableFunds == uint256(0)) return;

        _transferLiquidityLockerFunds(msg.sender, withdrawableFunds);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(withdrawableFunds);

        _updateFundsTokenBalance();
    }

    //TODO to be deactivated
    function withdrawFundsAmount(uint256 amount) public override {
        _whenProtocolNotPaused();
        uint256 withdrawableFunds = _prepareWithdraw(amount);
        require(
            amount <= withdrawableFunds,
            "P:INSUFFICIENT_WITHDRAWABLE_FUNDS"
        );

        if (withdrawableFunds == uint256(0)) return;

        _transferLiquidityLockerFunds(msg.sender, amount);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(amount);

        _updateFundsTokenBalance();
    }

    // Sets a Pool Admin. Only the Pool Delegate can call this function
    function setPoolAdmin(address poolAdmin, bool allowed) external {
        _isValidDelegateAndProtocolNotPaused();
        poolAdmins[poolAdmin] = allowed;
        emit PoolAdminSet(poolAdmin, allowed);
    }

    //TODO to be deactivated
    // Sets a Borrower. Only the Pool Delegate can call this function
    function setBorrower(address _borrower) external {
        require(_borrower != address(0), "P:ZERO_BORROWER");

        _isValidDelegateAndProtocolNotPaused();
        borrower = _borrower;
        emit BorrowerSet(borrower);
    }

    function setBlendedPool(address _blendedPool) external onlyOwner {
        blendedPool = BlendedPool(_blendedPool);
    }

    function _canWithdraw(address account, uint256 amount) internal view {
        require(
            depositDate[account].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );
        require(balanceOf(account) >= amount, "P:INSUFFICIENT_BALANCE");
        require(
            amount <= _balanceOfLiquidityLocker(),
            "P:INSUFFICIENT_LIQUIDITY"
        );
    }

    // Get drawdown available amount
    function _drawdownAmount() internal view returns (uint256) {
        return totalSupply() - principalOut;
    }

    // Get LiquidityLocker balance
    function _balanceOfLiquidityLocker() internal view returns (uint256) {
        return liquidityAsset.balanceOf(address(liquidityLocker));
    }

    // Checks that the current state of Pool matches the provided state
    function _isValidState(State _state) internal view {
        require(poolState == _state, "P:BAD_STATE");
    }

    // Checks that the protocol is not in a paused state
    function _whenProtocolNotPaused() internal view {
        require(!_globals(superFactory).protocolPaused(), "P:PROTO_PAUSED");
    }

    // Checks that `msg.sender` is the Pool Delegate and not paused
    function _isValidDelegateAndProtocolNotPaused() internal view {
        require(msg.sender == poolDelegate, "P:NOT_DEL");
        _whenProtocolNotPaused();
    }

    // Transfers Liquidity Asset to given `to` address
    function _transferLiquidityAssetFrom(
        address from,
        address to,
        uint256 value
    ) internal {
        liquidityAsset.safeTransferFrom(from, to, value);
    }

    // Returns the LiquidityLocker instance
    function _liquidityLocker() internal view returns (ILiquidityLocker) {
        return ILiquidityLocker(liquidityLocker);
    }

    // Returns the HeliosGlobals instance
    function _globals(
        address poolFactory
    ) internal view returns (IHeliosGlobals) {
        return IHeliosGlobals(IPoolFactory(poolFactory).globals());
    }

    // Checks that `msg.sender` is the Borrower
    modifier isBorrower() {
        require(msg.sender == borrower, "P:NOT_BORROWER");
        _;
    }
}
