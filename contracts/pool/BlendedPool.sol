// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../interfaces/IPoolFactory.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../library/PoolLib.sol";
import "../token/PoolFDT.sol";
import "../token/USDX.sol";

import "hardhat/console.sol";

// BlendedPool maintains all accounting and functionality related to Pools
contract BlendedPool is PoolFDT, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool
    address public immutable liquidityLocker; // The LiquidityLocker owned by this contractLiqui //note: to be removed
    address public immutable poolDelegate; // The Pool Delegate address, maintains full authority over the Pool
    IERC20 public immutable liquidityAsset; // The asset deposited by Lenders into the LiquidityLocker
    IERC20 public immutable rewardToken; // The asset which represents reward token i.e. real world money
    uint256 private immutable liquidityAssetDecimals; // The precision for the Liquidity Asset (i.e. `decimals()`)

    uint256 public principalOut; // The sum of all outstanding principal on Loans.
    address public borrower; // Address of borrower for this Pool.
    mapping(address => bool) public pools; //TODO

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 minInvestmentAmount;
    }

    PoolInfo public poolInfo;

    event PoolAdminSet(address indexed poolAdmin, bool allowed);
    event BorrowerSet(address indexed borrower);
    event BalanceUpdated(
        address indexed liquidityProvider,
        address indexed token,
        uint256 balance
    );
    event Deposit(address indexed investor, uint256 amount);
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

    mapping(address => uint256) public depositDate; // Used for deposit/withdraw logic

    constructor(
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount
    ) PoolFDT(PoolLib.NAME, PoolLib.SYMBOL) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_poolDelegate != address(0), "P:ZERO_POOL_DLG");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");

        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();

        superFactory = msg.sender;
        poolDelegate = _poolDelegate;

        poolInfo = PoolInfo(
            _lockupPeriod,
            _apy,
            _duration,
            _minInvestmentAmount
        );

        require(
            _globals(superFactory).isValidLiquidityAsset(_liquidityAsset),
            "P:INVALID_LIQ_ASSET"
        );

        liquidityLocker = address(
            ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset)
        );
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        require(amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");

        PoolLib.updateDepositDate(
            depositDate,
            balanceOf(msg.sender),
            amount,
            msg.sender
        );
        liquidityAsset.safeTransferFrom(msg.sender, address(this), amount); //note: we're transferring tokens to this contract's address, not "liquidity locker"

        _mint(msg.sender, amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, amount);
    }

    function withdrawableOf(address owner) external view returns (uint256) {
        require(
            depositDate[owner].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );

        return
            Math.min(
                liquidityAsset.balanceOf(liquidityLocker),
                super.balanceOf(owner)
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
            liquidityLocker,
            principalClaim.add(interestClaim)
        );
        updateFundsReceived();

        emit Payment(msg.sender, principalClaim, interestSum);
    }

    function decimals() public view override returns (uint8) {
        return uint8(liquidityAssetDecimals);
    }

    function withdrawFunds() public override whenNotPaused {
        withdrawableDividend = withdrawableFundsOf(msg.sender);
        withdrawFundsAmount(withdrawableDividend);
    }

    function withdrawFundsAmount(uint256 amount) public override whenNotPaused {
        require(
            depositDate[owner].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );
        require(withdrawableFundsOf(msg.sender) > 0, "P:NOT_INVESTOR");
        uint256 withdrawableFunds = _prepareWithdraw(amount);
        require(
            amount <= withdrawableFunds,
            "P:INSUFFICIENT_WITHDRAWABLE_FUNDS"
        );

        _transferLiquidityLockerFunds(msg.sender, amount);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(amount);

        _updateFundsTokenBalance();
    }

    //TODO implement check
    //TODO how do we assume if there is enough or not LA assets?
    /// @notice Used by Regional Pools to return LA to investors. Only RegPools can call it
    /// @param to investor's address
    /// @param value amount of LA the investor wants to withdraw
    function transferLiquidityLockerFunds(
        address to,
        uint value
    ) external onlyPool returns (bool) {

        //TODO implement check of LA
        _transferLiquidityLockerFunds(to, value);
    }

    // Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(
        address to,
        uint256 value
    ) internal returns (bool) {
        return _liquidityLocker().transfer(to, value);
    }

    // Emits a `BalanceUpdated` event for LiquidityLocker
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(
            liquidityLocker,
            address(liquidityAsset),
            _balanceOfLiquidityLocker()
        );
    }

    //TODO used for unhappy path
    function finishWithdrawalProcess() external onlyOwner {

    }

    modifier onlyPool() {
        require(pools[msg.sender], "P:NOT_POOL");
        _;
    }
}
