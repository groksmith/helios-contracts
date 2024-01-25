// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract AbstractPool is ERC20, ReentrancyGuard, Pausable, Ownable {
    string public constant NAME = "Helios TKN Pool";
    string public constant SYMBOL = "HLS-P";

    using SafeERC20 for IERC20;

    ILiquidityLocker public immutable liquidityLocker; // The LiquidityLocker owned by this contract
    IERC20 public immutable liquidityAsset; // The asset deposited by Lenders into the LiquidityLocker
    uint256 internal immutable liquidityAssetDecimals; // The precision for the Liquidity Asset (i.e. `decimals()`)
    uint256 internal totalMinted;
    uint256 public principalOut;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public pendingRewards;

    // TODO: Tigran. Not initialized?
    mapping(address => uint256) public depositDate; // Used for deposit/withdraw logic
    mapping(address => DepositInstance[]) public userDeposits;

    uint256 public withdrawLimit; // Maximum amount that can be withdrawn in a period
    uint256 public withdrawPeriod; // Timeframe for the withdrawal limit

    event Deposit(address indexed investor, uint256 indexed amount);
    event Withdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawalConcluded(address indexed investor, uint256 indexed amount);
    event RewardClaimed(address indexed recipient, uint256 indexed amount);
    event Reinvest(address indexed investor, uint256 indexed amount);
    event PendingReward(address indexed recipient, uint256 indexed amount);
    event PendingRewardConcluded(address indexed recipient, uint256 indexed amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 indexed amount);
    event BalanceUpdated(address indexed liquidityProvider, address indexed token, uint256 balance);

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
        uint256 withdrawThreshold;
    }

    struct DepositInstance {
        IERC20 token;
        uint256 amount;
        uint256 unlockTime;
    }

    PoolInfo public poolInfo;

    constructor(
        address _liquidityAsset,
        address _llFactory,
        string memory tokenName,
        string memory tokenSymbol,
        uint256 _withdrawLimit,
        uint256 _withdrawPeriod
    ) ERC20(tokenName, tokenSymbol) {
        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();
        liquidityLocker = ILiquidityLocker(ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset));
        withdrawLimit = _withdrawLimit;
        withdrawPeriod = _withdrawPeriod;
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external virtual whenNotPaused nonReentrant {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");

        IERC20 mainLA = liquidityLocker.liquidityAsset();

        depositLogic(_amount, mainLA);
    }

    /// @notice used to deposit secondary liquidity assets (non-USDT)
    /// @param _assetAddr the address of the stablecoin
    function depositSecondaryAsset(uint256 _amount, address _assetAddr) external whenNotPaused nonReentrant {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");
        require(liquidityLocker.secondaryAssetExists(_assetAddr), "P:UNKNOWN_ASSET");

        IERC20 token = IERC20(_assetAddr);

        depositLogic(_amount, token);
    }

    function depositLogic(uint256 _amount, IERC20 _token) internal {
        userDeposits[msg.sender].push(
            DepositInstance({token: _token, amount: _amount, unlockTime: block.timestamp + withdrawPeriod})
        );

        _token.safeTransferFrom(msg.sender, address(liquidityLocker), _amount);

        _mint(msg.sender, _amount);
        totalMinted += _amount;

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, _amount);
    }

    /// @notice withdraws the caller's liquidity assets
    /// @param  _amounts the amount of LA to be withdrawn
    /// @param  _indices the indices of the DepositInstance
    function withdraw(uint256[] calldata _amounts, uint16[] calldata _indices) public whenNotPaused {
        for (uint256 i = 0; i < _indices.length; i++) {
            uint256 _index = _indices[i];
            uint256 _amount = _amounts[i];
            require(_index < userDeposits[msg.sender].length, "P:INVALID_INDEX");
            DepositInstance memory aDeposit = userDeposits[msg.sender][_index];
            require(block.timestamp >= aDeposit.unlockTime, "P:TOKENS_LOCKED");
            require(aDeposit.amount >= _amount && balanceOf(msg.sender) >= _amount, "P:INSUFFICIENT_FUNDS");

            _burn(msg.sender, _amount);

            //unhappy path - the withdrawal is then added in the 'pending' to be processed by the admin
            if (liquidityLocker.totalBalance() < _amount) {
                pendingWithdrawals[msg.sender] += _amount;
                emit PendingWithdrawal(msg.sender, _amount);
                continue;
            }

            aDeposit.amount -= _amount;

            // TODO: Tigran. Check what is it for?
            // uint256 tokenAmountInDeposit = aDeposit.token.balanceOf(address(liquidityLocker));

            if (aDeposit.amount == 0) {
                removeDeposit(msg.sender, _index);
            }

            _transferLiquidityLockerFunds(msg.sender, _amount);
            _emitBalanceUpdatedEvent();
            emit Withdrawal(msg.sender, _amount);
        }
    }

    function removeDeposit(address _user, uint256 _index) private {
        uint256 lastIndex = userDeposits[_user].length - 1;
        if (_index != lastIndex) {
            userDeposits[_user][_index] = userDeposits[_user][lastIndex];
        }
        userDeposits[_user].pop();
    }

    /// @notice Used to reinvest rewards into more LP tokens
    /// @param  _amount the amount of rewards to be converted into LP
    function reinvest(uint256 _amount) external {
        require(_amount > 0, "P:INVALID_VALUE");
        require(rewards[msg.sender] >= _amount, "P:INSUFFICIENT_BALANCE");

        _mint(msg.sender, rewards[msg.sender]);
        totalMinted += _amount;
        rewards[msg.sender] -= _amount;
        _emitBalanceUpdatedEvent();
        emit Reinvest(msg.sender, _amount);
    }

    /// @notice check how many funds
    function availableToWithdraw(address _user, uint256 _index) external view returns (uint256) {
        require(_index < userDeposits[_user].length, "P:INVALID_INDEX");
        DepositInstance memory depositInstance = userDeposits[_user][_index];
        if (block.timestamp >= depositInstance.unlockTime) {
            return depositInstance.amount;
        } else {
            return 0;
        }
    }

    function distributeRewards(uint256 _amount, address[] calldata _holders) external virtual;

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _recipient address of the recipient who didn't get the liquidity
    function concludePendingWithdrawal(address _recipient) external nonReentrant onlyOwner {
        uint256 amount = pendingWithdrawals[_recipient];
        require(liquidityLocker.transfer(_recipient, amount), "P:CONCLUDE_WITHDRAWAL_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingWithdrawals[_recipient];
        emit PendingWithdrawalConcluded(_recipient, amount);
    }

    /// @notice Admin function used for unhappy path after reward claiming failure
    /// @param _recipient address of the recipient who didn't get the reward
    function concludePendingReward(address _recipient) external nonReentrant onlyOwner {
        uint256 amount = pendingRewards[_recipient];
        require(liquidityLocker.transfer(_recipient, amount), "P:CONCLUDE_REWARD_FAILED");

        //remove from pendingWithdrawals mapping:
        delete pendingRewards[_recipient];
        emit PendingRewardConcluded(_recipient, amount);
    }

    /// @notice  Use the pool's money for investment
    function drawdown(address _to) external onlyOwner {
        uint256 amount = _drawdownAmount();
        _transferLiquidityLockerFunds(_to, amount);
    }

    /// @notice  Deposit LA without minimal threshold or getting LP in return
    function adminDeposit(uint256 _amount) external onlyOwner {
        require(liquidityAsset.balanceOf(msg.sender) >= _amount, "P:NOT_ENOUGH_BALANCE!!");

        liquidityAsset.safeTransferFrom(msg.sender, address(liquidityLocker), _amount);
    }

    function setSecondaryLiquidityAsset(address _liquidityAsset) external onlyOwner {
        liquidityLocker.setSecondaryLiquidityAsset(_liquidityAsset);
    }

    function deleteSecondaryLiquidityAsset(address _liquidityAsset) external {
        liquidityLocker.deleteSecondaryLiquidityAsset(_liquidityAsset);
    }

    function setSecondaryLiquidityAssets(address[] calldata _liquidityAssets) external {
        liquidityLocker.setSecondaryLiquidityAssets(_liquidityAssets);
    }

    function getLL() external view returns (address) {
        return address(liquidityLocker);
    }

    function claimReward() external virtual returns (bool);

    /// @notice  Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(address to, uint256 value) internal returns (bool) {
        return liquidityLocker.transfer(to, value);
    }

    // Get drawdown available amount
    function _drawdownAmount() internal view returns (uint256) {
        return totalSupply() - principalOut;
    }

    // Emits a `BalanceUpdated` event for LiquidityLocker
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(address(liquidityLocker), address(liquidityAsset), liquidityLocker.totalBalance());
    }
}
