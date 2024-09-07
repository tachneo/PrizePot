// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


// Define Uniswap Interfaces
interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract PrizePot is Context, IERC20, ReentrancyGuard, Pausable {

    using Address for address;

    string private _name = "Prize Pot";
    string private _symbol = "PPOT";
    uint8 private _decimals = 9;

    uint256 private _totalSupply = 1000000000000 * 10**9; // 1 trillion total supply
    uint256 public _maxTxAmount = 10000000000 * 10**9; // Max transaction size (1% of total supply)
    uint256 public _walletMax = 20000000000 * 10**9; // Max wallet size (2% of total supply)
    uint256 private minimumTokensBeforeSwap = 500000000 * 10**9; // 0.05% of total supply

    uint256 public whaleThreshold; // Threshold for large trades (set in constructor)
    uint256 public higherTaxRate = 15; // Set higher tax rate for large trades (15%)
    uint256 public whaleCooldown = 3600; // 1 hour cooldown for large trades (in seconds)

    mapping(address => uint256) private _lastWhaleTradeTime; // Track last whale trade time for addresses

    // Wallet Addresses for Distribution
    address payable public marketingWallet = payable(0x666eda6bD98e24EaF8bcA9D1DD46617ECd61E5b2);
    address payable public teamWallet = payable(0x0de504d353375A999d2d983eC37Ed6FFd186CbA1);
    address payable public liquidityWallet = payable(0x8aF9D64eF4Eea9806FD191a33493b238B90A4d86);
    address payable public donationWallet = payable(0xf1214dBF1D1285D293604601154327A78580E6A4);
    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWalletLimitExempt;
    mapping(address => bool) public isTxLimitExempt;
    mapping(address => bool) public isMarketPair;
    mapping(address => bool) private _isBlacklisted;

    mapping(address => address) public referrer;
    mapping(address => uint256) private _lastTxTime;

    uint256 public buyLiquidityFee = 2;
    uint256 public buyMarketingFee = 2;
    uint256 public buyTeamFee = 2;
    uint256 public buyDonationFee = 1;

    uint256 public sellLiquidityFee = 3;
    uint256 public sellMarketingFee = 2;
    uint256 public sellTeamFee = 3;
    uint256 public sellDonationFee = 1;

    uint256 public totalLiquidityShare = 4;
    uint256 public totalMarketingShare = 2;
    uint256 public totalTeamShare = 3;
    uint256 public totalDonationShare = 1;

    uint256 public totalTaxIfBuying;
    uint256 public totalTaxIfSelling;
    uint256 public totalDistributionShares;

    uint256 public maxGasPrice = 100 * 10**9; // 100 Gwei
    uint256 public txCooldownTime = 60; // 60 seconds cooldown between transactions

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public checkWalletLimit = true;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier antiBot(address sender) {
        require(block.timestamp - _lastTxTime[sender] >= txCooldownTime, "Cooldown: Please wait before sending again");
        _;
        _lastTxTime[sender] = block.timestamp;
    }

    modifier notBlacklisted(address account) {
        require(!_isBlacklisted[account], "This address is blacklisted");
        _;
    }

    modifier ensureGasPrice() {
        require(tx.gasprice <= maxGasPrice, "Gas price exceeds limit");
        _;
    }

    // Ownership management variables and functions
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Mainnet Uniswap Router Address
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        _owner = _msgSender(); // Set deployer as the initial owner

        // Initialize whaleThreshold inside the constructor using _totalSupply
        whaleThreshold = _totalSupply * 1 / 100; // 1% of total supply as whale transaction threshold

        isExcludedFromFee[address(this)] = true;
        isWalletLimitExempt[address(uniswapPair)] = true;
        isWalletLimitExempt[address(this)] = true;
        isTxLimitExempt[address(this)] = true;

        isMarketPair[address(uniswapPair)] = true;

        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;
        totalTaxIfSelling = sellLiquidityFee + sellMarketingFee + sellTeamFee + sellDonationFee;
        totalDistributionShares = totalLiquidityShare + totalMarketingShare + totalTeamShare + totalDonationShare;


        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // Function to transfer ownership to Gnosis Safe
    function transferOwnershipToSafe() external onlyOwner {
        transferOwnership(0xDD5F797E224014Ac85e2A6AD1420Ac0e8d424574); // Gnosis Safe address
    }

    // Add the ability to dynamically change the Uniswap router address
    function updateUniswapRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router address");
        IUniswapV2Router02 _newUniswapRouter = IUniswapV2Router02(newRouter);
        uniswapV2Router = _newUniswapRouter;
        uniswapPair = IUniswapV2Factory(_newUniswapRouter.factory()).createPair(address(this), _newUniswapRouter.WETH());
    }

    // Function to update the gas price limit
    function updateMaxGasPrice(uint256 newGasPrice) external onlyOwner {
        maxGasPrice = newGasPrice;
    }

    // Basic ERC20 Functions
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    // Transfer function
    function transfer(address recipient, uint256 amount) public override notBlacklisted(_msgSender()) antiBot(_msgSender()) ensureGasPrice nonReentrant whenNotPaused returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        rewardReferral(recipient, amount);  // Updated to use rewardReferral
        return true;
    }

    // View the allowance for a given spender from the owner
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    // Approve a spender to spend a certain amount
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // Transfer tokens from one address to another
    function transferFrom(address sender, address recipient, uint256 amount) public override notBlacklisted(sender) antiBot(sender) ensureGasPrice nonReentrant whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);  // Subtract the amount from the sender's allowance
        rewardReferral(recipient, amount);  // Updated to use rewardReferral
        return true;
    }

    // Add the missing _approve function
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // Ownership Transfer Functions
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _pendingOwner = newOwner;
        emit OwnershipTransferInitiated(_owner, newOwner);
    }

    function confirmOwnership() public {
        require(_msgSender() == _pendingOwner, "Ownable: only the pending owner can confirm");
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }

    // Taxes and Fee Settings
    uint256 public constant MAX_BUY_TAX = 10; // Max 10% buy tax
    uint256 public constant MAX_SELL_TAX = 10; // Max 10% sell tax

    function setBuyTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        require(newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee <= MAX_BUY_TAX, "Buy taxes exceed limit");
        buyLiquidityFee = newLiquidityFee;
        buyMarketingFee = newMarketingFee;
        buyTeamFee = newTeamFee;
        buyDonationFee = newDonationFee;
        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee; // Replace .add() with +
    }


    function setSellTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        require(newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee <= MAX_SELL_TAX, "Sell taxes exceed limit");
        sellLiquidityFee = newLiquidityFee;
        sellMarketingFee = newMarketingFee;
        sellTeamFee = newTeamFee;
        sellDonationFee = newDonationFee;
        totalTaxIfSelling = sellLiquidityFee + sellMarketingFee + sellTeamFee + sellDonationFee; // Replace .add() with +
    }


    // Wallet Limit and Max Transaction
    function enableDisableWalletLimit(bool newValue) external onlyOwner {
        checkWalletLimit = newValue;
    }

    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        _maxTxAmount = maxTxAmount;
    }

    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
    }

    // Swap and Liquify
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount <= _maxTxAmount || isTxLimitExempt[sender], "Transfer amount exceeds the maxTxAmount.");

        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;

        if (overMinTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) {
            if (contractTokenBalance > minimumTokensBeforeSwap) {
                contractTokenBalance = minimumTokensBeforeSwap;
            }
            swapAndLiquify(contractTokenBalance);
        }

        // Replace .sub() with the - operator
        _balances[sender] = _balances[sender] - amount;

        // Replace .add() with the + operator
        uint256 finalAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ? amount : takeFee(sender, recipient, amount);
        if (checkWalletLimit && !isWalletLimitExempt[recipient]) {
            require(balanceOf(recipient) + finalAmount <= _walletMax, "Wallet limit exceeded");
        }


        // Automatic token burn mechanism (1% of final amount)
        uint256 burnAmount = finalAmount * 1 / 100;  // 1% burn
        _burn(sender, burnAmount);

        finalAmount = finalAmount - burnAmount;  // Adjust final transfer amount after burn

        _balances[recipient] = _balances[recipient] + finalAmount;

        emit Transfer(sender, recipient, finalAmount);

    }

    function swapAndLiquify(uint256 tokens) private lockTheSwap {
        uint256 halfLiquidity = tokens / 2;
        uint256 otherHalf = tokens - halfLiquidity;

        uint256 initialBalance = address(this).balance;
        swapTokensForEth(otherHalf);
        uint256 newBalance = address(this).balance - initialBalance;

        addLiquidity(halfLiquidity, newBalance);
        emit SwapAndLiquify(otherHalf, newBalance, halfLiquidity);
    }


    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            _owner,
            block.timestamp
        );
    }
    // Fee Logic with Anti-Whale Mechanism
    function takeFee(address sender, address recipient, uint256 amount) private returns (uint256) {
        uint256 feeAmount = 0;

        // Check if the transaction amount exceeds the whale threshold
        if (amount >= whaleThreshold) {
            require(block.timestamp - _lastWhaleTradeTime[sender] >= whaleCooldown, "Anti-Whale: Cooldown in effect");

            // Apply a higher tax rate for whale transactions
            feeAmount = amount * higherTaxRate / 100;

            // Update the last trade time for the sender
            _lastWhaleTradeTime[sender] = block.timestamp;
        } else {
            // Apply regular tax rates for normal transactions
            if (isMarketPair[sender]) {
                feeAmount = amount * totalTaxIfBuying / 100;
            } else if (isMarketPair[recipient]) {
                feeAmount = amount * totalTaxIfSelling / 100;
            }
        }

        if (feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)] + feeAmount;
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount - feeAmount;  // Returning the amount after subtracting the fee
    }


    // Referral Program
    // Referral Program
    function setReferral(address _referrer) external {
        require(referrer[msg.sender] == address(0), "Referrer already set");
        require(_referrer != _msgSender(), "Cannot refer yourself");
        referrer[msg.sender] = _referrer;
    }

    function rewardReferral(address recipient, uint256 amount) private {
        address ref = referrer[recipient];
        if (ref != address(0)) {
            uint256 reward = amount / 100; // 1% referral reward
            _balances[ref] = _balances[ref] + reward;
            emit Transfer(address(this), ref, reward);
        }
    }


    // Blacklisting Malicious Addresses
    function blacklistAddress(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
    }

    // Airdrop Functionality
    function airdropTokens(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Mismatched arrays");
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(_owner, recipients[i], amounts[i]);
        }
    }

    // Burn Functionality (Deflationary Mechanism)
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account] - amount;  // Replace .sub() with -
        _totalSupply = _totalSupply - amount;  // Replace .sub() with -
        emit Transfer(account, address(0), amount);
    }


    // Vesting Mechanism
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 releaseTime;
        bool isActive; // New field to track if vesting is active
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Event to track vested token release
    event TokensReleased(address indexed beneficiary, uint256 amountReleased);

    // Set Vesting Schedule with additional checks
    function setVestingSchedule(address account, uint256 totalAmount, uint256 releaseTime) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(totalAmount > 0, "Total amount must be greater than zero");
        require(releaseTime > block.timestamp, "Release time must be in the future");

        vestingSchedules[account] = VestingSchedule(totalAmount, 0, releaseTime, true);
    }

    // Release vested tokens with additional security checks
    function releaseVestedTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];

        require(schedule.isActive, "No active vesting schedule");
        require(block.timestamp >= schedule.releaseTime, "Tokens are still locked");
        require(schedule.amountReleased < schedule.totalAmount, "All tokens have been released");

        uint256 amountToRelease = schedule.totalAmount - schedule.amountReleased;

        require(amountToRelease > 0, "No tokens available for release");

        // Update the released amount and deactivate vesting after full release
        schedule.amountReleased += amountToRelease;
        if (schedule.amountReleased >= schedule.totalAmount) {
            schedule.isActive = false; // Deactivate the vesting schedule
        }

        // Transfer the released tokens and emit event
        _transfer(address(this), msg.sender, amountToRelease);
        emit TokensReleased(msg.sender, amountToRelease);
    }

    receive() external payable {}
}
