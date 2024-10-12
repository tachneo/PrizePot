// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title PrizePot (PPOT) Smart Contract
 * @dev ERC20 Token with Fee Management, Automated Liquidity Provision, Staking, Enhanced Security Features, and Governance Mechanisms
 *
 * @custom:dev-run-script ./scripts/deploy.js
 */

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
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    // Event emitted when ownership is transferred
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
     * @dev Modifier to restrict function access to the owner only.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
        
    /**
     * @dev Allows the current owner to relinquish control of the contract.
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
     * @dev Locks the contract for the owner for the specified amount of time.
     * Can only be called by the current owner.
     */
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }
        
    /**
     * @dev Unlocks the contract for the owner after the lock time has passed.
     * Can only be called by the previous owner.
     */
    function unlock() public virtual {
        require(_previousOwner == _msgSender(), "Ownable: caller is not the previous owner");
        require(block.timestamp > _lockTime, "Ownable: contract is still locked");
        emit OwnershipTransferred(address(0), _previousOwner);
        _owner = _previousOwner;
    }
}

/**
 * @dev Interface defining the ERC20 standard functions and events.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);

    // ERC20 Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);
}

/**
 * @dev Library with utility functions related to the address type.
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * IMPORTANT:
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * IMPORTANT:
     * Because control is transferred to `recipient`, care must be taken
     * to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the checks-effects-interactions pattern.
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // Perform the call and check for success
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: ETH transfer failed");
    }
}

/**
 * @dev Reentrancy guard contract to prevent reentrant calls.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    
    uint256 private _status;
    
    constructor () {
        _status = _NOT_ENTERED;
    }
    
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Applying the nonReentrant modifier to functions ensures that there are no nested (reentrant) calls to them.
     */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        
        _status = _ENTERED;
        
        _;
        
        _status = _NOT_ENTERED;
    }
}

/**
 * @dev Interface for the Uniswap V2 Factory.
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

/**
 * @dev Interface for the Uniswap V2 Pair.
 */
interface IUniswapV2Pair {
    // ERC20 metadata functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
        
    // ERC20 supply and balance functions
    function totalSupply() external view returns (uint);
    function balanceOf(address owner_) external view returns (uint);
    function allowance(address owner_, address spender) external view returns (uint);

    // ERC20 approval and transfer functions
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from,address to,uint value) external returns (bool);

    // EIP-2612 permit functionality
    function permit(
        address owner_, 
        address spender, 
        uint value, 
        uint deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external;
        
    // Liquidity functions
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(
        uint amount0Out, 
        uint amount1Out, 
        address to, 
        bytes calldata data
    ) external;
    function skim(address to) external;
    function sync() external;

    // Initializes the pair
    function initialize(address, address) external;
}

/**
 * @dev Interface for the Uniswap V2 Router01.
 */
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    // Liquidity management functions
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
        
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
        
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
        
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
        
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external returns (uint amountA, uint amountB);
        
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);
        
    // Swap functions
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
        
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
        
    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
    )
        external
        payable
        returns (uint[] memory amounts);
        
    function swapTokensForExactETH(
        uint amountOut, 
        uint amountInMax, 
        address[] calldata path, 
        address to, 
        uint deadline
    )
        external
        returns (uint[] memory amounts);
        
    function swapExactTokensForETH(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
    )
        external
        returns (uint[] memory amounts);
        
    function swapETHForExactTokens(
        uint amountOut, 
        address[] calldata path, 
        address to, 
        uint deadline
    )
        external
        payable
        returns (uint[] memory amounts);

    // Utility functions
    function quote(
        uint amountA, 
        uint reserveA, 
        uint reserveB
    ) external pure returns (uint amountB);
        
    function getAmountOut(
        uint amountIn, 
        uint reserveIn, 
        uint reserveOut
    ) external pure returns (uint amountOut);
        
    function getAmountIn(
        uint amountOut, 
        uint reserveIn, 
        uint reserveOut
    ) external pure returns (uint amountIn);
        
    function getAmountsOut(
        uint amountIn, 
        address[] calldata path
    ) external view returns (uint[] memory amounts);
        
    function getAmountsIn(
        uint amountOut, 
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

/**
 * @dev Interface for the Uniswap V2 Router02, extending Router01 with additional functions.
 */
interface IUniswapV2Router02 is IUniswapV2Router01 {
    // Removes liquidity with support for fee on transfer tokens
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
        
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external returns (uint amountETH);

    // Swaps with support for fee on transfer tokens
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
        
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
        
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/**
 * @dev Main contract implementing the ERC20 token with additional features.
 */
contract PrizePot is Context, IERC20, Ownable, ReentrancyGuard {
        
    using Address for address payable;  // Using Address library for address type
        
    // Token details
    string private _name = "PrizePot";
    string private _symbol = "PPOT";
    uint8 private _decimals = 9;

    // Wallet addresses for marketing and team funds
    address payable public marketingWalletAddress;
    address payable public teamWalletAddress;
    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD; // Dead address for burning tokens
        
    // Mapping to keep track of each account's balance
    mapping (address => uint256) private _balances;
    // Mapping to keep track of allowances
    mapping (address => mapping (address => uint256)) private _allowances;
        
    // Mappings to manage fee and limit exemptions
    mapping (address => bool) public isExcludedFromFee;
    mapping (address => bool) public isWalletLimitExempt;
    mapping (address => bool) public isTxLimitExempt;
    mapping (address => bool) public isMarketPair;

    // Fees for buying (in basis points: 1 BP = 0.01%)
    uint256 public _buyLiquidityFeeBP = 200; // 2%
    uint256 public _buyMarketingFeeBP = 200; // 2%
    uint256 public _buyTeamFeeBP = 200; // 2%
        
    // Fees for selling (in basis points)
    uint256 public _sellLiquidityFeeBP = 200; // 2%
    uint256 public _sellMarketingFeeBP = 200; // 2%
    uint256 public _sellTeamFeeBP = 400; // 4%

    // Distribution shares (in basis points)
    uint256 public _liquidityShareBP = 400; // 4%
    uint256 public _marketingShareBP = 400; // 4%
    uint256 public _teamShareBP = 1600; // 16%

    // Total taxes (in basis points)
    uint256 public _totalTaxIfBuyingBP = 600; // 6%
    uint256 public _totalTaxIfSellingBP = 800; // 8%
    uint256 public _totalDistributionSharesBP = 2400; // 24%

    // Total supply and limits
    uint256 private _totalSupply = 10000000000000 * (10 ** _decimals);
    uint256 public _maxTxAmount = _totalSupply; 
    uint256 public _walletMax = _totalSupply;
    uint256 private minimumTokensBeforeSwap = _totalSupply / 100; // 1% of total supply

    // Maximum fee limits
    uint256 public constant MAX_TOTAL_FEE_BP = 2000; // Maximum total fee is 20%
    uint256 public constant MAX_INDIVIDUAL_FEE_BP = 1000; // Maximum individual fee is 10%

    // Minimum and maximum transaction and wallet limits
    uint256 public minTxAmount = _totalSupply / 10000; // Minimum 0.01% of total supply
    uint256 public maXtxAmounT = _totalSupply; // Max is total supply
    uint256 public minWalletLimit = _totalSupply / 10000; // Minimum 0.01% of total supply
    uint256 public maxWalleTlimiT = _totalSupply; // Max is total supply

    // Uniswap router and pair addresses
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;
        
    // Flags for swap and liquify functionality
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public swapAndLiquifyByLimitOnly = false;
    bool public checkWalletLimit = true;

    // Events related to swap and liquify
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
        
    // Events for token and ETH swaps
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
        
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );
        
    // Events for Ether and ERC20 withdrawals
    event EtherWithdrawn(address indexed owner, uint256 amount);
    event ERC20Withdrawn(address indexed owner, address indexed token, uint256 amount);
        
    // Modifier to prevent reentrancy during swap and liquify
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
        
    // ----------------- Staking Variables -----------------

    struct StakeInfo {
        uint256 amount;          // Amount of tokens staked
        uint256 rewardDebt;      // Reward debt
        uint256 lastStakeTime;   // Last time tokens were staked or rewards were claimed
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    uint256 public rewardRatePerSecond = 1; // Example: 1 PPOT per second per staked token (adjust as needed)
    uint256 public constant MAX_REWARD_RATE = 100; // Maximum reward rate per second
    uint256 public stakingStartTime;

    // Events for staking
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    // ----------------- Governance Variables -----------------

    // Governance parameters
    uint256 public constant GOVERNANCE_DELAY = 1 days; // Time delay for executing proposals

    // Multi-signature parameters
    uint256 public constant MIN_SIGNATURES = 2; // Minimum number of approvals required
    mapping(address => bool) public isSigner;
    address[] public signers;

    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        uint256 newRewardRate;
        uint256 proposedTime;
        uint256 executeTime;
        uint256 approvalCount;
        bool executed;
        mapping(address => bool) approvals;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    // Events for governance
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event RewardRateChangeProposed(uint256 indexed proposalId, address indexed proposer, uint256 newRate, uint256 executeTime);
    event ProposalApproved(uint256 indexed proposalId, address indexed approver);
    event RewardRateUpdated(uint256 indexed proposalId, uint256 newRate);
    
    // ----------------- Constructor -----------------
    
    // Constructor to initialize the contract
    constructor () ReentrancyGuard() {
        // Set the marketing and team wallet addresses
        marketingWalletAddress = payable(0x7184eAC82c0C3F6bcdFD1c28A508dC4a18120b1e); // Marketing Address
        teamWalletAddress = payable(0xa26809d31cf0cCd4d11C520F84CE9a6Fc4d4bb75); // Team Address
            
        // Initialize Uniswap router with the specified address
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E // Example: PancakeSwap Router on BSC
        ); 

        // Create a Uniswap pair for this token
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // Set the Uniswap router
        uniswapV2Router = _uniswapV2Router;
        // Approve the Uniswap router to spend the total supply of tokens
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        // Exclude owner and contract from fee
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
            
        // Calculate total taxes for buying and selling
        _totalTaxIfBuyingBP = _buyLiquidityFeeBP + _buyMarketingFeeBP + _buyTeamFeeBP;
        _totalTaxIfSellingBP = _sellLiquidityFeeBP + _sellMarketingFeeBP + _sellTeamFeeBP;
        _totalDistributionSharesBP = _liquidityShareBP + _marketingShareBP + _teamShareBP;

        // Exempt owner, Uniswap pair, and contract from wallet limit
        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(uniswapPair)] = true;
        isWalletLimitExempt[address(this)] = true;
            
        // Exempt owner and contract from transaction limit
        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        // Mark the Uniswap pair as a market pair
        isMarketPair[address(uniswapPair)] = true;

        // Assign the total supply to the owner
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);

        // Initialize staking start time
        stakingStartTime = block.timestamp;

        // Initialize governance signers
        // Add the deployer as the first signer
        isSigner[_msgSender()] = true;
        signers.push(_msgSender());
        emit SignerAdded(_msgSender());

        // Example: Add additional signers here if needed
        // isSigner[additionalSignerAddress] = true;
        // signers.push(additionalSignerAddress);
        // emit SignerAdded(additionalSignerAddress);
    }

    // ----------------- ERC20 Standard Functions -----------------
    
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
     * @dev Returns the decimals places of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the total supply of the token.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the balance of a specific account.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Returns the allowance of a spender for a specific owner.
     */
    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    /**
     * @dev Increases the allowance of a spender.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        require(spender != address(0), "PrizePot: increase allowance for zero address");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Decreases the allowance of a spender.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        require(spender != address(0), "PrizePot: decrease allowance for zero address");
        require(_allowances[_msgSender()][spender] >= subtractedValue, "PrizePot: decreased allowance below zero");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    /**
     * @dev Returns the minimum number of tokens required before a swap can occur.
     */
    function minimumTokensBeforeSwapAmount() public view returns (uint256) {
        return minimumTokensBeforeSwap;
    }

    /**
     * @dev Approves a spender to spend a specified amount of tokens on behalf of the caller.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), "PrizePot: approve to zero address");
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Internal function to handle approvals.
     */
    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "PrizePot: approve from zero address"); // Prevent approving from the zero address
        require(spender != address(0), "PrizePot: approve to zero address"); // Prevent approving to the zero address

        _allowances[owner_][spender] = amount; // Set the allowance
        emit Approval(owner_, spender, amount); // Emit Approval event
    }

    // ----------------- Administrative Functions -----------------
    
    /**
     * @dev Sets the market pair status for a specific account.
     * @param account The address to set as a market pair.
     * @param newValue The boolean value indicating market pair status.
     */
    function setMarketPairStatus(address account, bool newValue) public onlyOwner {
        isMarketPair[account] = newValue;
        emit MarketPairStatusUpdated(account, newValue);
    }

    /**
     * @dev Sets the transaction limit exemption status for a holder.
     * @param holder The address to set exemption status.
     * @param exempt The boolean value indicating exemption.
     */
    function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
        emit TxLimitExemptStatusUpdated(holder, exempt);
    }
        
    /**
     * @dev Sets the fee exemption status for a specific account.
     * @param account The address to set exemption status.
     * @param newValue The boolean value indicating exemption.
     */
    function setIsExcludedFromFee(address account, bool newValue) public onlyOwner {
        isExcludedFromFee[account] = newValue;
        emit FeeExemptionStatusUpdated(account, newValue);
    }

    /**
     * @dev Sets the buy taxes: liquidity, marketing, and team fees.
     * @param newLiquidityFeeBP New liquidity fee percentage in basis points.
     * @param newMarketingFeeBP New marketing fee percentage in basis points.
     * @param newTeamFeeBP New team fee percentage in basis points.
     */
    function setBuyTaxes(uint256 newLiquidityFeeBP, uint256 newMarketingFeeBP, uint256 newTeamFeeBP) external onlyOwner {
        require(newLiquidityFeeBP <= MAX_INDIVIDUAL_FEE_BP, "PrizePot: Liquidity fee too high");
        require(newMarketingFeeBP <= MAX_INDIVIDUAL_FEE_BP, "PrizePot: Marketing fee too high");
        require(newTeamFeeBP <= MAX_INDIVIDUAL_FEE_BP, "PrizePot: Team fee too high");

        uint256 totalFeeBP = newLiquidityFeeBP + newMarketingFeeBP + newTeamFeeBP;
        require(totalFeeBP <= MAX_TOTAL_FEE_BP, "PrizePot: Total fee too high");

        _buyLiquidityFeeBP = newLiquidityFeeBP;
        _buyMarketingFeeBP = newMarketingFeeBP;
        _buyTeamFeeBP = newTeamFeeBP;

        _totalTaxIfBuyingBP = _buyLiquidityFeeBP + _buyMarketingFeeBP + _buyTeamFeeBP;

        emit BuyTaxesUpdated(newLiquidityFeeBP, newMarketingFeeBP, newTeamFeeBP);
    }

    /**
     * @dev Sets the sell taxes: liquidity, marketing, and team fees.
     * @param newLiquidityFeeBP New liquidity fee percentage in basis points.
     * @param newMarketingFeeBP New marketing fee percentage in basis points.
     * @param newTeamFeeBP New team fee percentage in basis points.
     */
    function setSellTaxes(uint256 newLiquidityFeeBP, uint256 newMarketingFeeBP, uint256 newTeamFeeBP) external onlyOwner {
        require(newLiquidityFeeBP <= MAX_INDIVIDUAL_FEE_BP, "PrizePot: Liquidity fee too high");
        require(newMarketingFeeBP <= MAX_INDIVIDUAL_FEE_BP, "PrizePot: Marketing fee too high");
        require(newTeamFeeBP <= MAX_INDIVIDUAL_FEE_BP, "PrizePot: Team fee too high");

        uint256 totalFeeBP = newLiquidityFeeBP + newMarketingFeeBP + newTeamFeeBP;
        require(totalFeeBP <= MAX_TOTAL_FEE_BP, "PrizePot: Total fee too high");

        _sellLiquidityFeeBP = newLiquidityFeeBP;
        _sellMarketingFeeBP = newMarketingFeeBP;
        _sellTeamFeeBP = newTeamFeeBP;

        _totalTaxIfSellingBP = _sellLiquidityFeeBP + _sellMarketingFeeBP + _sellTeamFeeBP;

        emit SellTaxesUpdated(newLiquidityFeeBP, newMarketingFeeBP, newTeamFeeBP);
    }
        
    /**
     * @dev Sets the distribution shares for liquidity, marketing, and team.
     * @param newLiquidityShareBP New liquidity share percentage in basis points.
     * @param newMarketingShareBP New marketing share percentage in basis points.
     * @param newTeamShareBP New team share percentage in basis points.
     */
    function setDistributionSettings(uint256 newLiquidityShareBP, uint256 newMarketingShareBP, uint256 newTeamShareBP) external onlyOwner {
        _liquidityShareBP = newLiquidityShareBP;
        _marketingShareBP = newMarketingShareBP;
        _teamShareBP = newTeamShareBP;

        _totalDistributionSharesBP = _liquidityShareBP + _marketingShareBP + _teamShareBP;

        emit DistributionSettingsUpdated(newLiquidityShareBP, newMarketingShareBP, newTeamShareBP);
    }
        
    /**
     * @dev Sets the maximum transaction amount.
     * @param maxTxAmount New maximum transaction amount.
     */
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        require(maxTxAmount >= minTxAmount, "PrizePot: Max transaction amount too low");
        require(maxTxAmount <= maXtxAmounT, "PrizePot: Max transaction amount too high");
        _maxTxAmount = maxTxAmount;
        emit MaxTxAmountUpdated(maxTxAmount);
    }


    /**
     * @dev Enables or disables the wallet limit.
     * @param newValue Boolean indicating whether to enable or disable the wallet limit.
     */
    function enableDisableWalletLimit(bool newValue) external onlyOwner {
       checkWalletLimit = newValue;
       emit WalletLimitEnabled(newValue);
    }

    /**
     * @dev Sets the wallet limit exemption status for a holder.
     * @param holder The address to set exemption status.
     * @param exempt The boolean value indicating exemption.
     */
    function setIsWalletLimitExempt(address holder, bool exempt) external onlyOwner {
        isWalletLimitExempt[holder] = exempt;
        emit WalletLimitExemptStatusUpdated(holder, exempt);
    }

    /**
     * @dev Sets the maximum number of tokens a wallet can hold.
     * @param newLimit New wallet limit.
     */
    function setWalletLimit(uint256 newLimit) external onlyOwner {
        require(newLimit >= minWalletLimit, "PrizePot: Wallet limit too low");
        require(newLimit <= maxWalleTlimiT, "PrizePot: Wallet limit too high");
        _walletMax  = newLimit;
        emit WalletLimitUpdated(newLimit);
    }

    /**
     * @dev Sets the minimum number of tokens before a swap is triggered.
     * @param newLimit New minimum token threshold for swapping.
     */
    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
        emit NumTokensBeforeSwapUpdated(newLimit);
    }

    /**
     * @dev Enables or disables the swap and liquify feature.
     * @param _enabled Boolean indicating whether to enable or disable swap and liquify.
     */
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /**
     * @dev Sets whether swap and liquify should occur only when the threshold is reached.
     * @param newValue Boolean indicating the swap and liquify condition.
     */
    function setSwapAndLiquifyByLimitOnly(bool newValue) public onlyOwner {
        swapAndLiquifyByLimitOnly = newValue;
        emit SwapAndLiquifyByLimitOnlyUpdated(newValue);
    }
        
    /**
     * @dev Returns the circulating supply (total supply minus the balance of the dead address).
     */
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(deadAddress);
    }

    // ----------------- Withdrawal Functions -----------------

    /**
     * @dev Transfers Ether to a specified address.
     * @param recipient The address to receive Ether.
     * @param amount The amount of Ether to transfer in wei.
     */
    function transferToAddressETH(address payable recipient, uint256 amount) private {
        Address.sendValue(recipient, amount);
    }

    // Function to receive ETH from UniswapV2Router when swapping
    receive() external payable {}
        
    /**
     * @dev Transfers tokens to a specified address.
     * @param recipient The address to receive tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another using the allowance mechanism.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        // Decrease the allowance accordingly
        require(_allowances[sender][_msgSender()] >= amount, "PrizePot: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    // ----------------- Internal Transfer Function -----------------

    /**
     * @dev Internal function to handle transfers, including fee logic and swap & liquify.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(address sender, address recipient, uint256 amount) private nonReentrant returns (bool) {

        require(sender != address(0), "PrizePot: transfer from zero address"); // Prevent transfer from zero address
        require(recipient != address(0), "PrizePot: transfer to zero address"); // Prevent transfer to zero address

        if(inSwapAndLiquify) { 
            return _basicTransfer(sender, recipient, amount); // If already in swap and liquify, perform a basic transfer
        }
        else {
            if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
                require(amount <= _maxTxAmount, "PrizePot: exceeds maxTxAmount."); // Enforce max transaction limit
            }            

            uint256 contractTokenBalance = balanceOf(address(this)); // Get the contract's token balance
            bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;
                
            // Check if conditions are met to perform swap and liquify
            if (overMinimumTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) 
            {
                if(swapAndLiquifyByLimitOnly)
                    contractTokenBalance = minimumTokensBeforeSwap; // Use minimum tokens if swap by limit only
                swapAndLiquify(contractTokenBalance); // Perform swap and liquify
            }

            // Subtract the amount from the sender's balance
            _balances[sender] = _balances[sender] - amount;

            // Calculate the final amount after deducting fees if applicable
            uint256 finalAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ? 
                                         amount : takeFee(sender, recipient, amount);

            // Check wallet limit if applicable
            if(checkWalletLimit && !isWalletLimitExempt[recipient])
                require(balanceOf(recipient) + finalAmount <= _walletMax, "PrizePot: exceeds max wallet limit");

            // Add the final amount to the recipient's balance
            _balances[recipient] = _balances[recipient] + finalAmount;

            emit Transfer(sender, recipient, finalAmount); // Emit the transfer event
            return true;
        }
    }

    /**
     * @dev Performs a basic transfer without taking any fees.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender] - amount; // Subtract from sender
        _balances[recipient] = _balances[recipient] + amount; // Add to recipient
        emit Transfer(sender, recipient, amount); // Emit transfer event
        return true;
    }

    /**
     * @dev Handles swapping tokens for ETH and adding liquidity.
     * @param tAmount The amount of tokens to swap and liquify.
     */
    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        // Calculate tokens for liquidity
        uint256 tokensForLP = (tAmount * _liquidityShareBP) / _totalDistributionSharesBP / 2;
        uint256 tokensForSwap = tAmount - tokensForLP; // Remaining tokens to swap

        swapTokensForEth(tokensForSwap); // Swap tokens for ETH
        uint256 amountReceived = address(this).balance; // Get the ETH received from swap

        uint256 totalBNBFee = _totalDistributionSharesBP - (_liquidityShareBP / 2);
            
        // Calculate amounts for liquidity, team, and marketing
        uint256 amountBNBLiquidity = (amountReceived * _liquidityShareBP) / totalBNBFee / 2;
        uint256 amountBNBTeam = (amountReceived * _teamShareBP) / totalBNBFee;
        uint256 amountBNBMarketing = amountReceived - amountBNBLiquidity - amountBNBTeam;

        if(amountBNBMarketing > 0)
            transferToAddressETH(marketingWalletAddress, amountBNBMarketing); // Transfer to marketing wallet

        if(amountBNBTeam > 0)
            transferToAddressETH(teamWalletAddress, amountBNBTeam); // Transfer to team wallet

        if(amountBNBLiquidity > 0 && tokensForLP > 0)
            addLiquidity(tokensForLP, amountBNBLiquidity); // Add liquidity to Uniswap
    }
        
    /**
     * @dev Swaps a specified amount of tokens for ETH using Uniswap.
     * @param tokenAmount The amount of tokens to swap.
     */
    function swapTokensForEth(uint256 tokenAmount) private {
        // Generate the Uniswap pair path of token -> WETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve the router to spend tokens

        // Make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );
        
        emit SwapTokensForETH(tokenAmount, path); // Emit event after swap
    }


    /**
     * @dev Adds liquidity to Uniswap using the specified token and ETH amounts.
     * @param tokenAmount The amount of tokens to add to liquidity.
     * @param ethAmount The amount of ETH to add to liquidity.
     */
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private nonReentrant {
        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve token transfer to the router

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
     * @dev Takes fee on transactions based on whether it's a buy or sell.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     * @return The amount after deducting fees.
     */
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;
            
        if(isMarketPair[sender]) {
            feeAmount = (amount * _totalTaxIfBuyingBP) / 10000; // Calculate buy fee
        }
        else if(isMarketPair[recipient]) {
            feeAmount = (amount * _totalTaxIfSellingBP) / 10000; // Calculate sell fee
        }
            
        if(feeAmount > 0) {
            _balances[address(this)] += feeAmount; // Add fee to contract balance
            emit Transfer(sender, address(this), feeAmount); // Emit transfer event for fee
        }

        return amount - feeAmount; // Return the amount after fee deduction
    }
        
    // ----------------- Withdrawal Functions -----------------

    /**
     * @dev Withdraws Ether from the contract to the owner's address.
     * @param amount The amount of Ether to withdraw in wei.
     */
    function withdrawEther(uint256 amount) external onlyOwner nonReentrant {
        require(address(this).balance >= amount, "PrizePot: Insufficient Ether balance");
        payable(owner()).transfer(amount);
        emit EtherWithdrawn(owner(), amount);
    }

    /**
     * @dev Withdraws ERC20 tokens mistakenly sent to the contract.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     * @param tokenAmount The amount of tokens to withdraw.
     */
    function withdrawERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner nonReentrant {
        require(tokenAddress != address(this), "PrizePot: Cannot withdraw own tokens");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit ERC20Withdrawn(owner(), tokenAddress, tokenAmount);
    }

    // ----------------- Event Declarations for Enhanced Access Control Transparency -----------------
    
    /**
     * @dev Emitted when the market pair status of an account is updated.
     */
    event MarketPairStatusUpdated(address indexed account, bool newValue);

    /**
     * @dev Emitted when the transaction limit exemption status of a holder is updated.
     */
    event TxLimitExemptStatusUpdated(address indexed holder, bool exempt);

    /**
     * @dev Emitted when the fee exemption status of an account is updated.
     */
    event FeeExemptionStatusUpdated(address indexed account, bool newValue);

    /**
     * @dev Emitted when the buy taxes are updated.
     */
    event BuyTaxesUpdated(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP);

    /**
     * @dev Emitted when the sell taxes are updated.
     */
    event SellTaxesUpdated(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP);

    /**
     * @dev Emitted when the distribution shares are updated.
     */
    event DistributionSettingsUpdated(uint256 liquidityShareBP, uint256 marketingShareBP, uint256 teamShareBP);

    /**
     * @dev Emitted when the maximum transaction amount is updated.
     */
    event MaxTxAmountUpdated(uint256 maxTxAmount);

    /**
     * @dev Emitted when the wallet limit is enabled or disabled.
     */
    event WalletLimitEnabled(bool enabled);

    /**
     * @dev Emitted when the wallet limit exemption status of a holder is updated.
     */
    event WalletLimitExemptStatusUpdated(address indexed holder, bool exempt);

    /**
     * @dev Emitted when the wallet limit is updated.
     */
    event WalletLimitUpdated(uint256 newLimit);

    /**
     * @dev Emitted when the number of tokens before swap is updated.
     */
    event NumTokensBeforeSwapUpdated(uint256 newLimit);

    /**
     * @dev Emitted when swap and liquify by limit only is updated.
     */
    event SwapAndLiquifyByLimitOnlyUpdated(bool newValue);

    // ----------------- Staking Functions -----------------

    /**
     * @dev Allows a user to stake a specific amount of PPOT tokens.
     * @param amount The amount of PPOT tokens to stake.
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "PrizePot: Cannot stake zero tokens");
        require(balanceOf(msg.sender) >= amount, "PrizePot: Insufficient balance to stake");

        // Update rewards before staking
        _updateRewards(msg.sender);

        // Update staking info and state changes before external interactions
        _balances[msg.sender] = _balances[msg.sender] - amount;
        _balances[address(this)] = _balances[address(this)] + amount;
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].lastStakeTime = block.timestamp;
        totalStaked += amount;

        emit Staked(msg.sender, amount);

        // Transfer tokens from user to contract
        emit Transfer(msg.sender, address(this), amount);
    }

    /**
     * @dev Allows a user to unstake a specific amount of PPOT tokens.
     * @param amount The amount of PPOT tokens to unstake.
     */
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "PrizePot: Cannot unstake zero tokens");
        require(stakes[msg.sender].amount >= amount, "PrizePot: Insufficient staked balance");

        // Update rewards before unstaking
        _updateRewards(msg.sender);

        // Update staking info and state changes before external interactions
        stakes[msg.sender].amount -= amount;
        stakes[msg.sender].lastStakeTime = block.timestamp;
        totalStaked -= amount;

        // Transfer tokens back to user
        _balances[address(this)] = _balances[address(this)] - amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        emit Transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Allows a user to claim their staking rewards.
     */
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);
        uint256 reward = stakes[msg.sender].rewardDebt;
        require(reward > 0, "PrizePot: No rewards to claim");

        // Reset reward debt before external interactions
        stakes[msg.sender].rewardDebt = 0;

        // Mint new rewards to the user
        _balances[msg.sender] = _balances[msg.sender] + reward;
        _totalSupply += reward;
        emit Transfer(address(0), msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Internal function to update the staking rewards for a user.
     * @param user The address of the user.
     */
    function _updateRewards(address user) internal {
        if(stakes[user].amount > 0){
            uint256 stakingDuration = block.timestamp - stakes[user].lastStakeTime;
            uint256 reward = stakes[user].amount * rewardRatePerSecond * stakingDuration;
            stakes[user].rewardDebt += reward;
            stakes[user].lastStakeTime = block.timestamp;
        }
    }

    // ----------------- Governance Functions -----------------

    /**
     * @dev Adds a new signer. Only callable by the owner.
     * @param newSigner The address to be added as a signer.
     */
    function addSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "PrizePot: Cannot add zero address as signer");
        require(!isSigner[newSigner], "PrizePot: Address is already a signer");
        isSigner[newSigner] = true;
        signers.push(newSigner);
        emit SignerAdded(newSigner);
    }

    /**
     * @dev Removes an existing signer. Only callable by the owner.
     * @param signer The address to be removed from signers.
     */
    function removeSigner(address signer) external onlyOwner {
        require(isSigner[signer], "PrizePot: Address is not a signer");
        isSigner[signer] = false;

        // Remove signer from the signers array
        for(uint256 i = 0; i < signers.length; i++) {
            if(signers[i] == signer){
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        emit SignerRemoved(signer);
    }

    /**
     * @dev Proposes a change to the reward rate. Requires multi-signature approval and a time lock.
     * @param newRate The proposed new reward rate per second.
     */
    function proposeRewardRateChange(uint256 newRate) external onlySigner {
        require(newRate <= MAX_REWARD_RATE, "PrizePot: Reward rate too high");

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.newRewardRate = newRate;
        newProposal.proposedTime = block.timestamp;
        newProposal.executeTime = block.timestamp + GOVERNANCE_DELAY;
        newProposal.approvalCount = 0;
        newProposal.executed = false;

        emit RewardRateChangeProposed(proposalCount, msg.sender, newRate, newProposal.executeTime);
    }

    /**
     * @dev Approves a proposal. Only signers can approve.
     * @param proposalId The ID of the proposal to approve.
     */
    function approveProposal(uint256 proposalId) external onlySigner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "PrizePot: Proposal does not exist");
        require(!proposal.executed, "PrizePot: Proposal already executed");
        require(!proposal.approvals[msg.sender], "PrizePot: Already approved by this signer");

        proposal.approvals[msg.sender] = true;
        proposal.approvalCount += 1;

        emit ProposalApproved(proposalId, msg.sender);

        // If approval count reaches minimum signatures, execute the proposal
        if(proposal.approvalCount >= MIN_SIGNATURES && block.timestamp >= proposal.executeTime) {
            executeProposal(proposalId);
        }
    }

    /**
     * @dev Executes a proposal after the time lock and sufficient approvals.
     * @param proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint256 proposalId) public nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "PrizePot: Proposal does not exist");
        require(!proposal.executed, "PrizePot: Proposal already executed");
        require(proposal.approvalCount >= MIN_SIGNATURES, "PrizePot: Not enough approvals");
        require(block.timestamp >= proposal.executeTime, "PrizePot: Governance delay not passed");

        // Apply the proposed change
        rewardRatePerSecond = proposal.newRewardRate;

        proposal.executed = true;

        emit RewardRateUpdated(proposalId, proposal.newRewardRate);
    }

    /**
     * @dev Modifier to restrict access to only authorized signers.
     */
    modifier onlySigner() {
        require(isSigner[msg.sender], "PrizePot: Caller is not a signer");
        _;
    }

    // ----------------- Additional Administrative Functions -----------------

    /**
     * @dev Allows the owner to set the marketing wallet address.
     * @param newMarketingWallet The new marketing wallet address.
     */
    function setMarketingWalletAddress(address payable newMarketingWallet) external onlyOwner {
        require(newMarketingWallet != address(0), "PrizePot: Marketing wallet cannot be zero address");
        marketingWalletAddress = newMarketingWallet;
        emit MarketingWalletUpdated(newMarketingWallet);
    }

    /**
     * @dev Allows the owner to set the team wallet address.
     * @param newTeamWallet The new team wallet address.
     */
    function setTeamWalletAddress(address payable newTeamWallet) external onlyOwner {
        require(newTeamWallet != address(0), "PrizePot: Team wallet cannot be zero address");
        teamWalletAddress = newTeamWallet;
        emit TeamWalletUpdated(newTeamWallet);
    }

    /**
     * @dev Allows the owner to set the staking start time.
     * @param timestamp The new staking start timestamp.
     */
    function setStakingStartTime(uint256 timestamp) external onlyOwner {
        stakingStartTime = timestamp;
        emit StakingStartTimeUpdated(timestamp);
    }

    // ----------------- Events for Additional Administrative Functions -----------------

    /**
     * @dev Emitted when the marketing wallet address is updated.
     */
    event MarketingWalletUpdated(address newMarketingWallet);

    /**
     * @dev Emitted when the team wallet address is updated.
     */
    event TeamWalletUpdated(address newTeamWallet);

    /**
     * @dev Emitted when the staking start time is updated.
     */
    event StakingStartTimeUpdated(uint256 newTimestamp);
    // ----------------- Staking Functions -----------------

    /**
     * @dev Allows a user to stake a specific amount of PPOT tokens.
     * @param amount The amount of PPOT tokens to stake.
     */
    // Note: The 'stake' function has already been defined above with proper Checks-Effects-Interactions.
    // No additional code needed here.

    // ----------------- Governance Functions -----------------

    /**
     * @dev Proposes a change to the reward rate. Requires multi-signature approval and a time lock.
     * @param newRate The proposed new reward rate per second.
     */
    // Functionality already implemented above.

    // ----------------- Additional Functions -----------------

    /**
     * @dev Returns the list of current signers.
     */
    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    /**
     * @dev Returns the details of a specific proposal.
     * @param proposalId The ID of the proposal.
     * @return id The proposal ID.
     * @return proposer The address who proposed the change.
     * @return newRewardRate The proposed new reward rate.
     * @return proposedTime The time when the proposal was made.
     * @return executeTime The earliest time when the proposal can be executed.
     * @return approvalCount The number of approvals the proposal has received.
     * @return executed Whether the proposal has been executed.
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        uint256 newRewardRate,
        uint256 proposedTime,
        uint256 executeTime,
        uint256 approvalCount,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.newRewardRate,
            proposal.proposedTime,
            proposal.executeTime,
            proposal.approvalCount,
            proposal.executed
        );
    }

    /**
     * @dev Checks if a signer has approved a specific proposal.
     * @param proposalId The ID of the proposal.
     * @param signer The address of the signer.
     * @return approved True if the signer has approved the proposal, false otherwise.
     */
    function hasApproved(uint256 proposalId, address signer) external view returns (bool approved) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.approvals[signer];
    }

    // ----------------- Additional Administrative Functions -----------------
    
    // (Additional administrative functions can be added here as needed.)

}
