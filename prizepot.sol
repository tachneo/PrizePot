// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title PrizePot Token Contract
 * @dev ERC20 Token with advanced features including fees, anti-whale, vesting, buyback, governance, and cross-chain compatibility.
 */

// =========================
// Context Contract
// =========================

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

// =========================
// IERC20 Interface
// =========================

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address ownerAddr, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed ownerAddr, address indexed spender, uint256 value);
}

// =========================
// Ownable2Step Contract for Safer Ownership Transfers
// =========================

contract Ownable2Step is Context {
    address private _owner;
    address private _pendingOwner;

    error CallerIsNotOwner();
    error NewOwnerIsZeroAddress();
    error OnlyPendingOwnerCanAccept();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferInitiated(address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (_owner != _msgSender()) revert CallerIsNotOwner();
        _;
    }

    function initiateOwnershipTransfer(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert NewOwnerIsZeroAddress();
        _pendingOwner = newOwner;
        emit OwnershipTransferInitiated(newOwner);
    }

    function finalizeOwnershipTransfer() public {
        if (_pendingOwner != _msgSender()) revert OnlyPendingOwnerCanAccept();
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }
}

// =========================
// ReentrancyGuard Contract with Custom Error
// =========================

contract ReentrancyGuard {
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = 1;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }
}

// =========================
// Pausable Contract with Custom Errors
// =========================

contract Pausable is Context, Ownable2Step {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    error ContractIsPaused();
    error ContractIsNotPaused();

    constructor() {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        if (_paused) revert ContractIsPaused();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert ContractIsNotPaused();
        _;
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// =========================
// PrizePot Contract with All Issues Resolved
// =========================

contract PrizePot is Context, IERC20, Ownable2Step, ReentrancyGuard, Pausable {
    // Token details
    string private constant _name = "Prize Pot";
    string private constant _symbol = "PPOT";
    uint8 private constant _decimals = 9;
    uint256 private _totalSupply = 1_000_000_000_000 * (10 ** _decimals);

    // Mappings
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Fee exemptions
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWalletLimitExempt;
    mapping(address => bool) public isTxLimitExempt;

    // Anti-whale mechanism
    uint256 public whaleThreshold;
    uint256 public higherTaxRate = 15; // 15%
    uint256 public whaleCooldown = 1 hours;
    mapping(address => uint256) private _lastWhaleTradeTime;

    // Transaction limits
    uint256 public maxTxAmount = 10_000_000_000 * (10 ** _decimals);
    uint256 public walletMax = 20_000_000_000 * (10 ** _decimals);
    uint256 private constant _minimumTokensBeforeSwap = 500_000_000 * (10 ** _decimals);

    // Fee percentages
    uint256 public buyLiquidityFee = 2;
    uint256 public buyMarketingFee = 2;
    uint256 public buyTeamFee = 2;
    uint256 public buyDonationFee = 1;

    uint256 public sellLiquidityFee = 3;
    uint256 public sellMarketingFee = 2;
    uint256 public sellTeamFee = 3;
    uint256 public sellDonationFee = 1;

    // Total shares and taxes
    uint256 public totalTaxIfBuying;
    uint256 public totalTaxIfSelling;
    uint256 public totalDistributionShares;

    // Address constants
    address payable public marketingWallet;
    address payable public teamWallet;
    address payable public liquidityWallet;
    address payable public donationWallet;
    address public immutable deadAddress = address(0xdead);

    // Booleans
    bool private _inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public checkWalletLimit = true;

    // Vesting
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 releaseTime;
        bool isActive;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Anti-bot
    mapping(address => uint256) private _lastTxTime;
    uint256 public botCooldownTime = 30 seconds;

    // Governance
    struct Proposal {
        string description;
        uint256 voteCount;
        bool executed;
    }

    Proposal[] public proposals;
    mapping(address => mapping(uint256 => bool)) public hasVoted;

    // Buyback reserve
    uint256 public buybackReserve;

    // Events
    event TokensReleased(address indexed beneficiary, uint256 amountReleased);
    event VestingScheduleSet(address indexed account, uint256 totalAmount, uint256 releaseTime);
    event VestingTokensReleased(address indexed account, uint256 amount);
    event MaxTxAmountUpdated(uint256 newMaxTxAmount);
    event WalletMaxUpdated(uint256 newWalletMax);
    event ProposalCreated(uint256 indexed proposalId, string description);
    event ProposalExecuted(uint256 indexed proposalId);
    event BuybackAndBurn(uint256 amount);
    event CrossChainTransferInitiated(address recipient, uint256 amount, string destinationChain);
    event EtherWithdrawn(address indexed owner, uint256 amount);
    event AirdropExecuted(uint256 totalAddresses, uint256 totalAmount);

    // Custom Errors
    error TransferFromZeroAddress();
    error TransferToZeroAddress();
    error MaxTxLimitExceeded();
    error WalletLimitExceeded();
    error AntiWhaleCooldown();
    error ApproveFromZeroAddress();
    error ApproveToZeroAddress();
    error InsufficientBuybackReserve();
    error InsufficientBalance();
    error MustBeTokenHolder();
    error AlreadyVoted();
    error NotEnoughVotes();
    error RecipientsAmountsMismatch();
    error BurnFromZeroAddress();
    error BurnAmountExceedsBalance();
    error InvalidAccount();
    error AmountMustBeGreaterThanZero();
    error ReleaseTimeMustBeInFuture();
    error NoActiveSchedule();
    error TokensStillLocked();
    error AllTokensReleased();
    error NoTokensToRelease();
    error MaxTxAmountTooLow();
    error WalletMaxTooLow();
    error BuyTaxesExceedLimit();
    error SellTaxesExceedLimit();
    error NoEtherAvailable();
    error EtherWithdrawalFailed();
    error ArrayLengthExceedsLimit();

    // Modifiers
    modifier antiBot(address sender) {
        if (block.timestamp - _lastTxTime[sender] < botCooldownTime) revert AntiWhaleCooldown();
        _lastTxTime[sender] = block.timestamp;
        _;
    }

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    // Constructor
    constructor() payable {
        whaleThreshold = _totalSupply / 100;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;
        isWalletLimitExempt[deadAddress] = true;

        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;
        totalTaxIfSelling = sellLiquidityFee + sellMarketingFee + sellTeamFee + sellDonationFee;
        totalDistributionShares = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;

        // Initialize wallets
        marketingWallet = payable(0x666eda6bD98e24EaF8bcA9D1DD46617ECd61E5b2);
        teamWallet = payable(0x0de504d353375A999d2d983eC37Ed6FFd186CbA1);
        liquidityWallet = payable(0x8aF9D64eF4Eea9806FD191a33493b238B90A4d86);
        donationWallet = payable(0xf1214dBF1D1285D293604601154327A78580E6A4);

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // ERC20 Standard Functions
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address ownerAddr, address spender) public view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance < amount) revert InsufficientBalance();
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    // Ether Withdrawal
    function withdrawEther() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) revert NoEtherAvailable();
        (bool success, ) = owner().call{value: contractBalance}("");
        if (!success) revert EtherWithdrawalFailed();
        emit EtherWithdrawn(owner(), contractBalance);
    }

    // Internal Functions
    function _transfer(address sender, address recipient, uint256 amount) internal antiBot(sender) {
        if (sender == address(0)) revert TransferFromZeroAddress();
        if (recipient == address(0)) revert TransferToZeroAddress();

        if (!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
            if (amount > maxTxAmount) revert MaxTxLimitExceeded();
        }

        if (checkWalletLimit && !isWalletLimitExempt[recipient]) {
            if (_balances[recipient] + amount > walletMax) revert WalletLimitExceeded();
        }

        uint256 finalAmount = amount;

        if (!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
            finalAmount = _takeFee(sender, amount);
        }

        _balances[sender] -= amount;
        _balances[recipient] += finalAmount;

        emit Transfer(sender, recipient, finalAmount);
    }

    function _takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;

        if (amount >= whaleThreshold) {
            if (block.timestamp - _lastWhaleTradeTime[sender] < whaleCooldown) revert AntiWhaleCooldown();
            feeAmount = (amount * higherTaxRate) / 100;
            _lastWhaleTradeTime[sender] = block.timestamp;
        }

        if (feeAmount > 0) {
            _balances[address(this)] += feeAmount;
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount - feeAmount;
    }

    function _approve(address ownerAddr, address spender, uint256 amount) private {
        if (ownerAddr == address(0)) revert ApproveFromZeroAddress();
        if (spender == address(0)) revert ApproveToZeroAddress();

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    // Buyback and Burn Functionality
    function buybackAndBurn(uint256 amount) external onlyOwner {
        if (buybackReserve < amount) revert InsufficientBuybackReserve();
        buybackReserve -= amount;
        _burn(address(this), amount);
        emit BuybackAndBurn(amount);
    }

    // Cross-Chain Token Transfers
    function crossChainTransfer(address recipient, uint256 amount, string memory destinationChain) external
        nonReentrant
        whenNotPaused
    {
        if (_balances[_msgSender()] < amount) revert InsufficientBalance();
        _burn(_msgSender(), amount);
        emit CrossChainTransferInitiated(recipient, amount, destinationChain);
    }

    // Governance Proposal Mechanism
    function createProposal(string memory description) public onlyOwner {
        proposals.push(Proposal({
            description: description,
            voteCount: 0,
            executed: false
        }));
        emit ProposalCreated(proposals.length - 1, description);
    }

    function voteOnProposal(uint256 proposalIndex) public {
        if (_balances[_msgSender()] == 0) revert MustBeTokenHolder();
        if (hasVoted[_msgSender()][proposalIndex]) revert AlreadyVoted();
        proposals[proposalIndex].voteCount += _balances[_msgSender()];
        hasVoted[_msgSender()][proposalIndex] = true;
    }

    function executeProposal(uint256 proposalIndex) public onlyOwner {
        if (proposals[proposalIndex].voteCount <= _totalSupply / 2) revert NotEnoughVotes();
        proposals[proposalIndex].executed = true;
        emit ProposalExecuted(proposalIndex);
    }

    // Airdrop Functionality
    function airdropTokens(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant whenNotPaused {
        uint256 length = recipients.length;
        if (length != amounts.length) revert RecipientsAmountsMismatch();
        uint256 MAX_ARRAY_LENGTH = 100; // Limit to prevent gas issues
        if (length > MAX_ARRAY_LENGTH) revert ArrayLengthExceedsLimit();
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < length; ++i) {
            _transfer(_msgSender(), recipients[i], amounts[i]);
            totalAmount += amounts[i];
        }
        emit AirdropExecuted(length, totalAmount);
    }

    // Burn Functionality
    function burn(uint256 amount) external whenNotPaused nonReentrant {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert BurnFromZeroAddress();
        if (_balances[account] < amount) revert BurnAmountExceedsBalance();

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, deadAddress, amount);
    }

    // Vesting Mechanism
    function setVestingSchedule(address account, uint256 totalAmount, uint256 releaseTime) external onlyOwner {
        if (account == address(0)) revert InvalidAccount();
        if (totalAmount == 0) revert AmountMustBeGreaterThanZero();
        if (releaseTime <= block.timestamp) revert ReleaseTimeMustBeInFuture();

        VestingSchedule storage schedule = vestingSchedules[account];
        schedule.totalAmount = totalAmount;
        schedule.amountReleased = 0;
        schedule.releaseTime = releaseTime;
        schedule.isActive = true;

        emit VestingScheduleSet(account, totalAmount, releaseTime);
    }

    function releaseVestedTokens() external nonReentrant whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[_msgSender()];
        if (!schedule.isActive) revert NoActiveSchedule();
        if (block.timestamp < schedule.releaseTime) revert TokensStillLocked();
        if (schedule.amountReleased >= schedule.totalAmount) revert AllTokensReleased();

        uint256 amountToRelease = schedule.totalAmount - schedule.amountReleased;
        if (amountToRelease == 0) revert NoTokensToRelease();

        schedule.amountReleased = schedule.totalAmount;
        schedule.isActive = false;

        _transfer(address(this), _msgSender(), amountToRelease);
        emit VestingTokensReleased(_msgSender(), amountToRelease);
        emit TokensReleased(_msgSender(), amountToRelease);
    }

    // Owner Functions
    function updateMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        if (newMaxTxAmount < _totalSupply / 1000) revert MaxTxAmountTooLow();
        maxTxAmount = newMaxTxAmount;
        emit MaxTxAmountUpdated(newMaxTxAmount);
    }

    function setWalletMax(uint256 newWalletMax) external onlyOwner {
        if (newWalletMax < _totalSupply / 500) revert WalletMaxTooLow();
        walletMax = newWalletMax;
        emit WalletMaxUpdated(newWalletMax);
    }

    function setBuyTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        uint256 MAX_BUY_TAX = 10;
        if (newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee > MAX_BUY_TAX) revert BuyTaxesExceedLimit();
        buyLiquidityFee = newLiquidityFee;
        buyMarketingFee = newMarketingFee;
        buyTeamFee = newTeamFee;
        buyDonationFee = newDonationFee;
        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;
    }

    function setSellTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        uint256 MAX_SELL_TAX = 10;
        if (newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee > MAX_SELL_TAX) revert SellTaxesExceedLimit();
        sellLiquidityFee = newLiquidityFee;
        sellMarketingFee = newMarketingFee;
        sellTeamFee = newTeamFee;
        sellDonationFee = newDonationFee;
        totalTaxIfSelling = sellLiquidityFee + sellMarketingFee + sellTeamFee + sellDonationFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setCheckWalletLimit(bool _enabled) external onlyOwner {
        checkWalletLimit = _enabled;
    }

    // Fallback Functions
    receive() external payable {
        // Allow contract to receive Ether
        // Added revert to prevent unintended Ether transfers
        if (msg.value > 0) revert();
    }
}
