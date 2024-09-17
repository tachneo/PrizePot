// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * @title PrizePot Token Contract
 * @dev ERC20 Token with advanced features including fees, anti-whale, vesting, and more.
 */

// =========================
// Libraries and Interfaces
// =========================

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. 
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // Silence state mutability warning without generating bytecode
        return msg.data;
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    // ERC20 Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    
    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    
    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    
    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    
    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    
    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
    
    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    
    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e., `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
    
    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    
    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use `abi.decode`.
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    
    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }
    
    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    
    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }
    
    /**
     * @dev Internal function to perform a function call with value.
     */
    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }   
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function waiveOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    
    /**
     * @dev Returns the unlock time if the contract is locked.
     */
    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }
    
    /**
     * @dev Returns the current block timestamp.
     */
    function getTime() public view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @dev Locks the contract for the owner for a certain period.
     * Can only be called by the current owner.
     */
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }
    
    /**
     * @dev Unlocks the contract and restores ownership to the previous owner.
     * Can only be called by the previous owner after the lock time has passed.
     */
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is locked");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 */
contract ReentrancyGuard {
    uint256 private _status;
    
    constructor () {
        _status = 1;
    }
    
    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");
        
        _status = 2;
        
        _;
        
        _status = 1;
    }
}

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 */
contract Pausable is Context, Ownable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);
    
    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);
    
    bool private _paused;
    
    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor () {
        _paused = false;
    }
    
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    
    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    
    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    
    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() public virtual onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    
    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public virtual onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// =========================
// PrizePot Token Contract
// =========================

/**
 * @title PrizePot
 * @dev ERC20 Token with advanced features such as fees, anti-whale, vesting, and more.
 */
contract PrizePot is Context, IERC20, Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using Address for address payable;

    // Token Details
    string private _name = "Prize Pot";
    string private _symbol = "PPOT";
    uint8 private _decimals = 9;
    uint256 private _totalSupply = 1_000_000_000_000 * 10**_decimals; // 1 Trillion Tokens

    // Mappings for balances and allowances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Fee Exemptions
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWalletLimitExempt;
    mapping(address => bool) public isTxLimitExempt;
    mapping(address => bool) public isMarketPair;
    mapping(address => bool) private _isBlacklisted;

    // Referral System
    mapping(address => address) public referrer;

    // Anti-Whale Mechanism
    uint256 public whaleThreshold;
    uint256 public higherTaxRate = 15; // 15%
    uint256 public whaleCooldown = 1 hours;
    mapping(address => uint256) private lastWhaleTradeTime;

    // Transaction Limits
    uint256 public maxTxAmount = 10_000_000_000 * 10**_decimals; // 1% of total supply
    uint256 public walletMax = 20_000_000_000 * 10**_decimals; // 2% of total supply
    uint256 private minimumTokensBeforeSwap = 500_000_000 * 10**_decimals; // 0.05% of total supply

    // Fees and Shares
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

    // Gas Price and Transaction Cooldown
    uint256 public maxGasPrice = 100 gwei;
    uint256 public txCooldownTime = 60; // 60 seconds

    // Wallet Addresses for Distribution
    address payable public marketingWallet = payable(0x666eda6bD98e24EaF8bcA9D1DD46617ECd61E5b2);
    address payable public teamWallet = payable(0x0de504d353375A999d2d983eC37Ed6FFd186CbA1);
    address payable public liquidityWallet = payable(0x8aF9D64eF4Eea9806FD191a33493b238B90A4d86);
    address payable public donationWallet = payable(0xf1214dBF1D1285D293604601154327A78580E6A4);
    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD;

    // Uniswap Router and Pair
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    // Swap and Liquify Flags
    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public checkWalletLimit = true;

    // Vesting Structure
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 releaseTime;
        bool isActive;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Events
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);
    event TokensReleased(address indexed beneficiary, uint256 amountReleased);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event VestingScheduleSet(address indexed account, uint256 totalAmount, uint256 releaseTime);
    event VestingTokensReleased(address indexed account, uint256 amount);
    event ReferralSet(address indexed user, address indexed referrer);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Modifiers
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

    // Constructor
    constructor() {
        // Initialize Uniswap Router
        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Mainnet Router
        uniswapPair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());

        // Approve maximum tokens for Uniswap Router
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        // Anti-Whale Threshold
        whaleThreshold = _totalSupply.div(100); // 1% of total supply

        // Exemptions
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;
        isWalletLimitExempt[deadAddress] = true;

        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        isMarketPair[uniswapPair] = true;

        // Calculate Total Taxes
        totalTaxIfBuying = buyLiquidityFee.add(buyMarketingFee).add(buyTeamFee).add(buyDonationFee);
        totalTaxIfSelling = sellLiquidityFee.add(sellMarketingFee).add(sellTeamFee).add(sellDonationFee);
        totalDistributionShares = totalLiquidityShare.add(totalMarketingShare).add(totalTeamShare).add(totalDonationShare);

        // Assign total supply to the owner
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // =========================
    // ERC20 Standard Functions
    // =========================

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address ownerAddr, address spender) public view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transfer}.
     * Includes anti-whale, fees, and referral reward mechanisms.
     */
    function transfer(address recipient, uint256 amount) public override 
        notBlacklisted(_msgSender()) 
        antiBot(_msgSender()) 
        ensureGasPrice 
        nonReentrant 
        whenNotPaused 
        returns (bool) 
    {
        _transfer(_msgSender(), recipient, amount);
        rewardReferral(recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     * Includes anti-whale, fees, and referral reward mechanisms.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override 
        notBlacklisted(sender) 
        antiBot(sender) 
        ensureGasPrice 
        nonReentrant 
        whenNotPaused 
        returns (bool) 
    {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        rewardReferral(recipient, amount);
        return true;
    }

    // =========================
    // Internal Functions
    // =========================

    /**
     * @dev Internal function to transfer tokens, handle fees, and enforce limits.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // Check transaction limits
        if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        // Check wallet limits
        if(checkWalletLimit && !isWalletLimitExempt[recipient]) {
            require(balanceOf(recipient).add(amount) <= walletMax, "Wallet limit exceeded");
        }

        // Check if contract needs to swap tokens
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;

        if(overMinTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) {
            contractTokenBalance = minimumTokensBeforeSwap;
            swapAndLiquify(contractTokenBalance);
        }

        // Calculate final amount after fees
        uint256 finalAmount = isExcludedFromFee[sender] || isExcludedFromFee[recipient] ? amount : takeFee(sender, recipient, amount);

        // Update balances
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(finalAmount);
        
        emit Transfer(sender, recipient, finalAmount);
    }

    /**
     * @dev Internal function to handle fee deduction and distribution.
     */
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;

        // Anti-Whale Check
        if(amount >= whaleThreshold) {
            require(block.timestamp - lastWhaleTradeTime[sender] >= whaleCooldown, "Anti-Whale: Cooldown in effect");
            feeAmount = amount.mul(higherTaxRate).div(100);
            lastWhaleTradeTime[sender] = block.timestamp;
        }
        else {
            if(isMarketPair[sender]) {
                feeAmount = amount.mul(totalTaxIfBuying).div(100);
            }
            else if(isMarketPair[recipient]) {
                feeAmount = amount.mul(totalTaxIfSelling).div(100);
            }
        }

        if(feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount.sub(feeAmount);
    }

    /**
     * @dev Internal function to swap tokens for ETH and add liquidity.
     */
    function swapAndLiquify(uint256 tokens) private lockTheSwap {
        // Split the contract balance into halves
        uint256 halfLiquidity = tokens.mul(totalLiquidityShare).div(totalDistributionShares).div(2);
        uint256 otherHalf = tokens.sub(halfLiquidity);

        // Swap tokens for ETH
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(tokens.mul(totalLiquidityShare).div(totalDistributionShares).sub(halfLiquidity));
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // Add liquidity to Uniswap
        addLiquidity(halfLiquidity, newBalance);

        emit SwapAndLiquify(halfLiquidity, newBalance, halfLiquidity);
    }

    /**
     * @dev Internal function to swap tokens for ETH.
     */
    function swapTokensForEth(uint256 tokenAmount) private {
        // Generate the Uniswap pair path of token -> WETH
        address;
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // Approve token transfer to Uniswap Router
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Internal function to add liquidity to Uniswap.
     */
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // Approve token transfer to Uniswap Router
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // Slippage is unavoidable
            0, // Slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    /**
     * @dev Internal function to approve tokens.
     */
    function _approve(address ownerAddr, address spender, uint256 amount) private {
        require(ownerAddr != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    // =========================
    // Referral System
    // =========================

    /**
     * @dev Allows a user to set their referrer. Can only be set once.
     */
    function setReferral(address _referrer) external {
        require(referrer[msg.sender] == address(0), "Referrer already set");
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(_referrer != address(0), "Referrer cannot be zero address");

        referrer[msg.sender] = _referrer;
        emit ReferralSet(msg.sender, _referrer);
    }

    /**
     * @dev Internal function to reward referrers.
     */
    function rewardReferral(address recipient, uint256 amount) internal {
        address _referrer = referrer[recipient];
        if(_referrer != address(0)) {
            uint256 reward = amount.div(100); // 1% referral reward
            _balances[_referrer] = _balances[_referrer].add(reward);
            emit Transfer(address(this), _referrer, reward);
        }
    }

    // =========================
    // Blacklist Functionality
    // =========================

    /**
     * @dev Allows the owner to blacklist or unblacklist an address.
     */
    function blacklistAddress(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
        emit BlacklistUpdated(account, value);
    }

    // =========================
    // Airdrop Functionality
    // =========================

    /**
     * @dev Allows the owner to airdrop tokens to multiple addresses.
     */
    function airdropTokens(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Mismatched arrays");
        for(uint256 i = 0; i < recipients.length; i++) {
            _transfer(_msgSender(), recipients[i], amounts[i]);
        }
    }

    // =========================
    // Burn Functionality
    // =========================

    /**
     * @dev Allows a user to burn their own tokens.
     */
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Internal function to burn tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, deadAddress, amount);
    }

    // =========================
    // Vesting Mechanism
    // =========================

    /**
     * @dev Sets a vesting schedule for an account.
     */
    function setVestingSchedule(address account, uint256 totalAmount, uint256 releaseTime) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(totalAmount > 0, "Total amount must be greater than zero");
        require(releaseTime > block.timestamp, "Release time must be in the future");

        vestingSchedules[account] = VestingSchedule({
            totalAmount: totalAmount,
            amountReleased: 0,
            releaseTime: releaseTime,
            isActive: true
        });

        emit VestingScheduleSet(account, totalAmount, releaseTime);
    }

    /**
     * @dev Allows beneficiaries to release their vested tokens after the release time.
     */
    function releaseVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.isActive, "No active vesting schedule");
        require(block.timestamp >= schedule.releaseTime, "Tokens are still locked");
        require(schedule.amountReleased < schedule.totalAmount, "All tokens have been released");

        uint256 amountToRelease = schedule.totalAmount.sub(schedule.amountReleased);
        require(amountToRelease > 0, "No tokens available for release");

        schedule.amountReleased = schedule.amountReleased.add(amountToRelease);
        if(schedule.amountReleased >= schedule.totalAmount) {
            schedule.isActive = false;
        }

        _transfer(address(this), msg.sender, amountToRelease);
        emit VestingTokensReleased(msg.sender, amountToRelease);
        emit TokensReleased(msg.sender, amountToRelease);
    }

    // =========================
    // Owner Functions
    // =========================

    /**
     * @dev Allows the owner to update the Uniswap router address.
     */
    function updateUniswapRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router address");
        uniswapV2Router = IUniswapV2Router02(newRouter);
        uniswapPair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
    }

    /**
     * @dev Allows the owner to update the maximum gas price.
     */
    function updateMaxGasPrice(uint256 newGasPrice) external onlyOwner {
        require(newGasPrice > 0, "Gas price must be greater than zero");
        maxGasPrice = newGasPrice;
    }

    /**
     * @dev Allows the owner to update the transaction cooldown time.
     */
    function updateTxCooldownTime(uint256 newCooldown) external onlyOwner {
        require(newCooldown >= 30, "Cooldown too short");
        txCooldownTime = newCooldown;
    }

    /**
     * @dev Allows the owner to set the maximum transaction amount.
     */
    function setMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        require(newMaxTxAmount >= _totalSupply.div(1000), "MaxTxAmount too low"); // At least 0.1%
        maxTxAmount = newMaxTxAmount;
    }

    /**
     * @dev Allows the owner to set the maximum wallet size.
     */
    function setWalletMax(uint256 newWalletMax) external onlyOwner {
        require(newWalletMax >= _totalSupply.div(500), "WalletMax too low"); // At least 0.2%
        walletMax = newWalletMax;
    }

    /**
     * @dev Allows the owner to set the minimum tokens before swap.
     */
    function setMinimumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
    }

    /**
     * @dev Allows the owner to enable or disable swap and liquify.
     */
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    /**
     * @dev Allows the owner to enable or disable wallet limit checks.
     */
    function setCheckWalletLimit(bool _enabled) external onlyOwner {
        checkWalletLimit = _enabled;
    }

    /**
     * @dev Allows the owner to set buy taxes.
     */
    uint256 public constant MAX_BUY_TAX = 10; // 10%
    function setBuyTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        require(newLiquidityFee.add(newMarketingFee).add(newTeamFee).add(newDonationFee) <= MAX_BUY_TAX, "Buy taxes exceed limit");
        buyLiquidityFee = newLiquidityFee;
        buyMarketingFee = newMarketingFee;
        buyTeamFee = newTeamFee;
        buyDonationFee = newDonationFee;
        totalTaxIfBuying = buyLiquidityFee.add(buyMarketingFee).add(buyTeamFee).add(buyDonationFee);
    }

    /**
     * @dev Allows the owner to set sell taxes.
     */
    uint256 public constant MAX_SELL_TAX = 10; // 10%
    function setSellTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        require(newLiquidityFee.add(newMarketingFee).add(newTeamFee).add(newDonationFee) <= MAX_SELL_TAX, "Sell taxes exceed limit");
        sellLiquidityFee = newLiquidityFee;
        sellMarketingFee = newMarketingFee;
        sellTeamFee = newTeamFee;
        sellDonationFee = newDonationFee;
        totalTaxIfSelling = sellLiquidityFee.add(sellMarketingFee).add(sellTeamFee).add(sellDonationFee);
    }

    // =========================
    // Blacklist Management
    // =========================

    /**
     * @dev Allows the owner to blacklist or unblacklist an address.
     */
    function blacklistAddress(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
        emit BlacklistUpdated(account, value);
    }

    // =========================
    // Vesting Management
    // =========================

    /**
     * @dev Sets a vesting schedule for an account.
     */
    function setVestingSchedule(address account, uint256 totalAmount, uint256 releaseTime) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(totalAmount > 0, "Total amount must be greater than zero");
        require(releaseTime > block.timestamp, "Release time must be in the future");

        vestingSchedules[account] = VestingSchedule({
            totalAmount: totalAmount,
            amountReleased: 0,
            releaseTime: releaseTime,
            isActive: true
        });

        emit VestingScheduleSet(account, totalAmount, releaseTime);
    }

    /**
     * @dev Allows beneficiaries to release their vested tokens after the release time.
     */
    function releaseVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.isActive, "No active vesting schedule");
        require(block.timestamp >= schedule.releaseTime, "Tokens are still locked");
        require(schedule.amountReleased < schedule.totalAmount, "All tokens have been released");

        uint256 amountToRelease = schedule.totalAmount.sub(schedule.amountReleased);
        require(amountToRelease > 0, "No tokens available for release");

        schedule.amountReleased = schedule.amountReleased.add(amountToRelease);
        if(schedule.amountReleased >= schedule.totalAmount) {
            schedule.isActive = false;
        }

        _transfer(address(this), msg.sender, amountToRelease);
        emit VestingTokensReleased(msg.sender, amountToRelease);
        emit TokensReleased(msg.sender, amountToRelease);
    }

    // =========================
    // Referral System Management
    // =========================

    /**
     * @dev Allows a user to set their referrer. Can only be set once.
     */
    function setReferral(address _referrer) external {
        require(referrer[msg.sender] == address(0), "Referrer already set");
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(_referrer != address(0), "Referrer cannot be zero address");

        referrer[msg.sender] = _referrer;
        emit ReferralSet(msg.sender, _referrer);
    }

    /**
     * @dev Internal function to reward referrers.
     */
    function rewardReferral(address recipient, uint256 amount) internal {
        address _referrer = referrer[recipient];
        if(_referrer != address(0)) {
            uint256 reward = amount.div(100); // 1% referral reward
            _balances[_referrer] = _balances[_referrer].add(reward);
            emit Transfer(address(this), _referrer, reward);
        }
    }

    // =========================
    // Fallback Functions
    // =========================

    /**
     * @dev Fallback function to receive ETH from Uniswap.
     */
    receive() external payable {}
    
    fallback() external payable {}
}

// =========================
// Uniswap Interfaces
// =========================

/**
 * @dev Interface for Uniswap V2 Router
 */
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

/**
 * @dev Interface for Uniswap V2 Factory
 */
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    
    function createPair(address tokenA, address tokenB) external returns (address pair);
    
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
