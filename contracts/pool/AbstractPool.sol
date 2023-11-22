// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../token/PoolFDT.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";
import "../library/PoolLib.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract AbstractPool is PoolFDT, Pausable, Ownable {
    using SafeERC20 for IERC20;

    ILiquidityLocker public immutable liquidityLocker; // The LiquidityLocker owned by this contractLiqui //note: to be removed
    IERC20 public immutable liquidityAsset; // The asset deposited by Lenders into the LiquidityLocker
    uint256 internal immutable liquidityAssetDecimals; // The precision for the Liquidity Asset (i.e. `decimals()`)

    mapping(address => uint) public rewards;
    mapping(address => uint) public pendingWithdrawals;
    mapping(address => uint) public pendingRewards;
    mapping(address => uint256) public depositDate; // Used for deposit/withdraw logic

    event Deposit(address indexed investor, uint256 amount);
    event Withdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawal(address indexed investor, uint256 amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 amount);
    event RewardClaimed(address indexed recipient, uint256 amount);
    event PendingReward(address indexed recipient, uint256 amount);
    event PendingRewardConcluded(address indexed recipient, uint256 amount);

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
    }

    PoolInfo public poolInfo;

    constructor(
        address _liquidityAsset,
        address _llFactory,
        string memory tokenName,
        string memory tokenSymbol
    ) PoolFDT(tokenName, tokenSymbol) {
        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();
        liquidityLocker = ILiquidityLocker(
            ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset)
        );
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");

        PoolLib.updateDepositDate(
            depositDate,
            balanceOf(msg.sender),
            _amount,
            msg.sender
        );
        liquidityAsset.safeTransferFrom(
            msg.sender,
            address(liquidityLocker),
            _amount
        );

        _mint(msg.sender, _amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, _amount);
    }

    /// @notice withdraw's the caller's liquidity assets
    /// @param  _amount the amount of LA to be withdrawn
    function withdraw(uint256 _amount) public whenNotPaused returns (bool) {
        require(balanceOf(msg.sender) >= _amount, "P:INSUFFICIENT_BALANCE");
        require(
            depositDate[msg.sender] + poolInfo.lockupPeriod <= block.timestamp,
            "P:FUNDS_LOCKED"
        );

        _burn(msg.sender, _amount);

        //unhappy path - the withdrawal is then added in the 'pending' to be processed by the admin
        if (liquidityLocker.totalBalance() < _amount) {
            pendingWithdrawals[msg.sender] += _amount;
            emit PendingWithdrawal(msg.sender, _amount);
            return false;
        }

        // uint256 withdrawableFunds = _prepareWithdraw(_amount);
        _transferLiquidityLockerFunds(msg.sender, _amount);
        _emitBalanceUpdatedEvent();
        emit Withdrawal(msg.sender, _amount);
        return true;
    }

    /// @notice Used to distribute rewards among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list investors must be provided externally due to Solidity limitations
    function distributeRewards(
        uint256 _amount,
        address[] calldata _holders
    ) external onlyOwner nonReentrant {
        require(_amount > 0, "P:ZERO_CLAIM");
        require(_holders.length > 0, "P:ZERO_HOLDERS");
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (_amount * holderBalance) / totalSupply();
            rewards[holder] += holderShare;
        }
    }

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _recipient address of the recipient who didn't get the liquidities
    function concludePendingWithdrawal(address _recipient) external onlyOwner {
        uint256 amount = pendingWithdrawals[_recipient];
        require(
            liquidityLocker.transfer(_recipient, amount),
            "P:CONCLUDE_WITHDRAWAL_FAILED"
        );

        //remove from pendingWithdrawals mapping:
        delete pendingWithdrawals[_recipient];
        emit PendingWithdrawalConcluded(_recipient, amount);
    }

    /// @notice Admin function used for unhappy path after reward claiming failure
    /// @param _recipient address of the recipient who didn't get the reward
    function concludePendingReward(address _recipient) external onlyOwner {
        uint256 amount = pendingRewards[_recipient];
        require(
            liquidityLocker.transfer(_recipient, amount),
            "P:CONCLUDE_REWARD_FAILED"
        );

        //remove from pendingWithdrawals mapping:
        delete pendingRewards[_recipient];
        emit PendingRewardConcluded(_recipient, amount);
    }

    function claimReward() external virtual returns (bool);

    /// @notice  Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(
        address to,
        uint256 value
    ) internal returns (bool) {
        return liquidityLocker.transfer(to, value);
    }

    // Emits a `BalanceUpdated` event for LiquidityLocker
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(
            address(liquidityLocker),
            address(liquidityAsset),
            liquidityLocker.totalBalance()
        );
    }
}
