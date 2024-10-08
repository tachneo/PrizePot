// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title PrizePot (PPOT) Smart Contract
 * @dev ERC20 Token with Fee Management and Automated Liquidity Provision
 *
 * @custom:dev-run-script ./scripts/deploy.js
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
 * @dev Abstract contract providing information about the current execution context.
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

    // Initializes the contract setting the deployer as the initial owner
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    // Returns the address of the current owner
    function owner() public view returns (address) {
        return _owner;
    }   
        
    // Modifier to restrict function access to the owner only
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
        
    // Allows the current owner to relinquish control of the contract
    function waiveOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    // Transfers ownership of the contract to a new account (`newOwner`)
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // Returns the unlock time if the contract is locked
    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }
        
    // Returns the current block timestamp
    function getTime() public view returns (uint256) {
        return block.timestamp;
    }

    // Locks the contract for the owner for the specified amount of time
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_previousOwner, address(0));
    }
        
    // Unlocks the contract for the owner after the lock time has passed
    function unlock() public virtual {
        require(_previousOwner == _msgSender(), "Ownable: caller is not the previous owner");
        require(block.timestamp > _lockTime, "Ownable: contract is still locked");
        emit OwnershipTransferred(address(0), _previousOwner);
        _owner = _previousOwner;
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

    // Wallet addresses for marketing and team funds (Set once in constructor)
    address payable public immutable marketingWalletAddress;
    address payable public immutable teamWalletAddress;
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

    // Fees for buying
    uint256 public _buyLiquidityFee = 2;
    uint256 public _buyMarketingFee = 2;
    uint256 public _buyTeamFee = 2;
        
    // Fees for selling
    uint256 public _sellLiquidityFee = 2;
    uint256 public _sellMarketingFee = 2;
    uint256 public _sellTeamFee = 4;

    // Distribution shares
    uint256 public _liquidityShare = 4;
    uint256 public _marketingShare = 4;
    uint256 public _teamShare = 16;

    // Total taxes
    uint256 public _totalTaxIfBuying = 6;
    uint256 public _totalTaxIfSelling = 8;
    uint256 public _totalDistributionShares = 24;

    // Total supply and limits
    uint256 private _totalSupply = 10000000000000 * (10 ** _decimals);
    uint256 public _maxTxAmount = _totalSupply; 
    uint256 public _walletMax = _totalSupply;
    uint256 private minimumTokensBeforeSwap = _totalSupply; 

    // Maximum fee limits
    uint256 public constant MAX_TOTAL_FEE = 20; // Maximum total fee is 20%
    uint256 public constant MAX_INDIVIDUAL_FEE = 10; // Maximum individual fee is 10%

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
        
    // Modifier to prevent reentrancy during swap and liquify
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
        
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
        _totalTaxIfBuying = _buyLiquidityFee + _buyMarketingFee + _buyTeamFee;
        _totalTaxIfSelling = _sellLiquidityFee + _sellMarketingFee + _sellTeamFee;
        _totalDistributionShares = _liquidityShare + _marketingShare + _teamShare;

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
    }

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

    /**
     * @dev Sets the market pair status for a specific account.
     */
    function setMarketPairStatus(address account, bool newValue) public onlyOwner {
        isMarketPair[account] = newValue;
    }

    /**
     * @dev Sets the transaction limit exemption status for a holder.
     */
    function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
    }
        
    /**
     * @dev Sets the fee exemption status for a specific account.
     */
    function setIsExcludedFromFee(address account, bool newValue) public onlyOwner {
        isExcludedFromFee[account] = newValue;
    }

    /**
     * @dev Sets the buy taxes: liquidity, marketing, and team fees.
     */
    function setBuyTaxes(uint256 newLiquidityTax, uint256 newMarketingTax, uint256 newTeamTax) external onlyOwner {
        require(newLiquidityTax <= MAX_INDIVIDUAL_FEE, "PrizePot: Liquidity fee too high");
        require(newMarketingTax <= MAX_INDIVIDUAL_FEE, "PrizePot: Marketing fee too high");
        require(newTeamTax <= MAX_INDIVIDUAL_FEE, "PrizePot: Team fee too high");

        uint256 totalFee = newLiquidityTax + newMarketingTax + newTeamTax;
        require(totalFee <= MAX_TOTAL_FEE, "PrizePot: Total fee too high");

        _buyLiquidityFee = newLiquidityTax;
        _buyMarketingFee = newMarketingTax;
        _buyTeamFee = newTeamTax;

        _totalTaxIfBuying = _buyLiquidityFee + _buyMarketingFee + _buyTeamFee;
    }

    /**
     * @dev Sets the sell taxes: liquidity, marketing, and team fees.
     */
    function setSellTaxes(uint256 newLiquidityTax, uint256 newMarketingTax, uint256 newTeamTax) external onlyOwner {
        require(newLiquidityTax <= MAX_INDIVIDUAL_FEE, "PrizePot: Liquidity fee too high");
        require(newMarketingTax <= MAX_INDIVIDUAL_FEE, "PrizePot: Marketing fee too high");
        require(newTeamTax <= MAX_INDIVIDUAL_FEE, "PrizePot: Team fee too high");

        uint256 totalFee = newLiquidityTax + newMarketingTax + newTeamTax;
        require(totalFee <= MAX_TOTAL_FEE, "PrizePot: Total fee too high");

        _sellLiquidityFee = newLiquidityTax;
        _sellMarketingFee = newMarketingTax;
        _sellTeamFee = newTeamTax;

        _totalTaxIfSelling = _sellLiquidityFee + _sellMarketingFee + _sellTeamFee;
    }
        
    /**
     * @dev Sets the distribution shares for liquidity, marketing, and team.
     */
    function setDistributionSettings(uint256 newLiquidityShare, uint256 newMarketingShare, uint256 newTeamShare) external onlyOwner {
        _liquidityShare = newLiquidityShare;
        _marketingShare = newMarketingShare;
        _teamShare = newTeamShare;

        _totalDistributionShares = _liquidityShare + _marketingShare + _teamShare;
    }
        
    /**
     * @dev Sets the maximum transaction amount.
     */
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        require(maxTxAmount >= minTxAmount, "PrizePot: Max transaction amount too low");
        require(maxTxAmount <= maXtxAmounT, "PrizePot: Max transaction amount too high");
        _maxTxAmount = maxTxAmount;
    }


    /**
     * @dev Enables or disables the wallet limit.
     */
    function enableDisableWalletLimit(bool newValue) external onlyOwner {
       checkWalletLimit = newValue;
    }

    /**
     * @dev Sets the wallet limit exemption status for a holder.
     */
    function setIsWalletLimitExempt(address holder, bool exempt) external onlyOwner {
        isWalletLimitExempt[holder] = exempt;
    }

    /**
     * @dev Sets the maximum number of tokens a wallet can hold.
     */
    function setWalletLimit(uint256 newLimit) external onlyOwner {
        require(newLimit >= minWalletLimit, "PrizePot: Wallet limit too low");
        require(newLimit <= maxWalleTlimiT, "PrizePot: Wallet limit too high");
        _walletMax  = newLimit;
    }

    /**
     * @dev Sets the minimum number of tokens before a swap is triggered.
     */
    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
    }

    /**
     * @dev Enables or disables the swap and liquify feature.
     */
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /**
     * @dev Sets whether swap and liquify should occur only when the threshold is reached.
     */
    function setSwapAndLiquifyByLimitOnly(bool newValue) public onlyOwner {
        swapAndLiquifyByLimitOnly = newValue;
    }
        
    /**
     * @dev Returns the circulating supply (total supply minus the balance of the dead address).
     */
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(deadAddress);
    }

    /**
     * @dev Transfers Ether to a specified address.
     */
    function transferToAddressETH(address payable recipient, uint256 amount) private {
        Address.sendValue(recipient, amount);
    }


     // Function to receive ETH from UniswapV2Router when swapping
    receive() external payable {}
        
    /**
     * @dev Transfers tokens to a specified address.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another using the allowance mechanism.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        // Decrease the allowance accordingly
        require(_allowances[sender][_msgSender()] >= amount, "PrizePot: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    /**
     * @dev Internal function to handle transfers, including fee logic and swap & liquify.
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
     */
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender] - amount; // Subtract from sender
        _balances[recipient] = _balances[recipient] + amount; // Add to recipient
        emit Transfer(sender, recipient, amount); // Emit transfer event
        return true;
    }

    /**
     * @dev Handles swapping tokens for ETH and adding liquidity.
     */
    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        // Calculate tokens for liquidity
        uint256 tokensForLP = (tAmount * _liquidityShare) / _totalDistributionShares / 2;
        uint256 tokensForSwap = tAmount - tokensForLP; // Remaining tokens to swap

        swapTokensForEth(tokensForSwap); // Swap tokens for ETH
        uint256 amountReceived = address(this).balance; // Get the ETH received from swap

        uint256 totalBNBFee = _totalDistributionShares - (_liquidityShare / 2);
            
        // Calculate amounts for liquidity, team, and marketing
        uint256 amountBNBLiquidity = (amountReceived * _liquidityShare) / totalBNBFee / 2;
        uint256 amountBNBTeam = (amountReceived * _teamShare) / totalBNBFee;
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
     */
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;
            
        if(isMarketPair[sender]) {
            feeAmount = (amount * _totalTaxIfBuying) / 100; // Calculate buy fee
        }
        else if(isMarketPair[recipient]) {
            feeAmount = (amount * _totalTaxIfSelling) / 100; // Calculate sell fee
        }
            
        if(feeAmount > 0) {
            _balances[address(this)] += feeAmount; // Add fee to contract balance
            emit Transfer(sender, address(this), feeAmount); // Emit transfer event for fee
        }

        return amount - feeAmount; // Return the amount after fee deduction
    }
        
}
