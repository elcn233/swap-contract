// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.5.6;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SwapContract {
    address public owner;
    address public usdtAddress; // USDT contract address
    mapping(address => uint256) public rates; // route to rate
    uint256 public constant RATE_PRECISION = 10**8; // 8 decimal places for precision

    event SwapUsdtToToken(address indexed user, address indexed token, uint256 usdtAmount, uint256 tokenAmount);
    event SwapTokenToUsdt(address indexed user, address indexed token, uint256 tokenAmount, uint256 usdtAmount);
    event SwapTokenToToken(address indexed user, address indexed fromToken, address indexed toToken, uint256 fromAmount, uint256 toAmount);
    event Withdraw(address indexed owner, address indexed asset, uint256 amount);
    event SetRate(address indexed route, uint256 rate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _usdtAddress) public {
        owner = msg.sender;
        usdtAddress = _usdtAddress;
    }

    function setRate(address route, uint256 rate) public onlyOwner {
        rates[route] = rate;
        emit SetRate(route, rate);
    }

    function getRate(address route) public view returns (uint256) {
        return rates[route];
    }

    function swapUsdtToToken(address tokenAddress, uint256 usdtAmount) public {
        require(rates[tokenAddress] > 0, "Rate not set");
        uint256 tokenAmount = usdtAmount * (rates[tokenAddress] / RATE_PRECISION);
        IERC20 usdt = IERC20(usdtAddress);
        IERC20 token = IERC20(tokenAddress);
        require(usdt.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient contract token balance");
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
        emit SwapUsdtToToken(msg.sender, tokenAddress, usdtAmount, tokenAmount);
    }

    function swapTokenToUsdt(address tokenAddress, uint256 tokenAmount) public {
        require(rates[tokenAddress] > 0, "Rate not set");
        uint256 usdtAmount = tokenAmount / (rates[tokenAddress] / RATE_PRECISION);
        IERC20 token = IERC20(tokenAddress);
        IERC20 usdt = IERC20(usdtAddress);
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        require(usdt.balanceOf(address(this)) >= usdtAmount, "Insufficient contract USDT balance");
        require(usdt.transfer(msg.sender, usdtAmount), "USDT transfer failed");
        emit SwapTokenToUsdt(msg.sender, tokenAddress, tokenAmount, usdtAmount);
    }

    function swapTokenToToken(address fromTokenAddress, address toTokenAddress, uint256 fromAmount) public {
        require(rates[fromTokenAddress] > 0 && rates[toTokenAddress] > 0, "Rate not set");
        uint256 usdtAmount = fromAmount / (rates[fromTokenAddress] / RATE_PRECISION);
        uint256 toAmount = usdtAmount * (rates[toTokenAddress] / RATE_PRECISION);
        IERC20 fromToken = IERC20(fromTokenAddress);
        IERC20 toToken = IERC20(toTokenAddress);
        IERC20 usdt = IERC20(usdtAddress);
        require(fromToken.transferFrom(msg.sender, address(this), fromAmount), "From token transfer failed");
        require(usdt.balanceOf(address(this)) >= usdtAmount, "Insufficient contract USDT balance");
        require(usdt.transfer(address(this), usdtAmount), "USDT transfer failed");
        require(toToken.balanceOf(address(this)) >= toAmount, "Insufficient contract token balance");
        require(toToken.transfer(msg.sender, toAmount), "To token transfer failed");
        emit SwapTokenToToken(msg.sender, fromTokenAddress, toTokenAddress, fromAmount, toAmount);
    }

    function withdrawEth(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract ETH balance");
        msg.sender.transfer(amount);
        emit Withdraw(msg.sender, address(0), amount);
    }
    
    function withdrawToken(address tokenAddress, uint256 amount) public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient contract token balance");
        require(token.transfer(msg.sender, amount), "Token transfer failed");
        emit Withdraw(msg.sender, tokenAddress, amount);
    }
}
