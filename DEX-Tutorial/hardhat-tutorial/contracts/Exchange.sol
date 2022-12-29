// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {

    address public cryptoDevTokenAddress;

    // @dev Exchange is inheriting ERC20, because our exchange will keep track of Crypto Dev LP tokens
    // @param _CryptoDevToken - takes in the address of the CryptoDev token. Cannot be null
    constructor(address _CryptoDevToken) ERC20("CryptoDev LP Token", "CDLP") {
        require(_CryptoDevToken != address(0), "Token address passed is a null address");
        cryptoDevTokenAddress = _CryptoDevToken;
    }

    // @dev Returns the amount of 'Crypto Dev Token's held by the contract
    // @dev Eth reserves can be found using address(this).balance
    function getReserve() public view returns (uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    // @dev Adds liquidity to the exchange
    // @param _amount - The amount of 'Crypto Dev' tokens to be added as liquidity
    function addLiquidity(uint256 _amount) public payable returns (uint256) {
        uint256 liquidity;
        uint256 ethBalance = address(this).balance;
        uint256 cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        // If the reserve is empty, intake any user supplied value for 
        // 'Ether' and 'Crypto Dev' tokens because there is currently no ratio
        // Transfer the 'Crypto Dev' tokens from the user's account to the contract 
        // Take the current ethBalance and mint `ethBalance` amount of LP tokens to the user.
        // `Liquidity` provided is equal to `ethBalance` because this is the first time user
        // is adding `Eth` to the contract, so whatever `Eth` contract has is equal to the one supplied
        // by the user in the current `addLiquidity` call
        // `Liquidity` tokens that need to be minted to the user on `addLiquidity` call should always be proportional
        // to the Eth specified by the user
        if(cryptoDevTokenReserve == 0) {
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        } 
        // If the reserve is not empty, intake any user supplied value for
        // `Ether` and determine according to the ratio how many `Crypto Dev` tokens need to be supplied 
        // to prevent any large price impacts because of the additional liquidity.
        // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user.
        // Ratio here is -> 
        // (cryptoDevTokenAmount user can add / cryptoDevTokenReserve in the contract) = (Eth Sent by the user / Eth Reserve in the contract);
        // So doing some maths ->
        // (cryptoDevTokenAmount user can add) = (Eth Sent by the user * cryptoDevTokenReserve /Eth Reserve);
        // 
        // Transfer only (cryptoDevTokenAmount user can add) amount of `Crypto Dev tokens` from users account to the contract
        // The amount of LP tokens that would be sent to the user should be proportional to the liquidity of
        // ether added by the user
        // Ratio here to be maintained is ->
        // (LP tokens to be sent to the user (liquidity)/ totalSupply of LP tokens in contract) = (Eth sent by the user)/(Eth reserve in the contract)
        // by some maths -> 
        // liquidity =  (totalSupply of LP tokens in contract * (Eth sent by the user))/(Eth reserve in the contract)
        else {
            uint256 ethReserve = ethBalance - msg.value;
            uint256 cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve)/(ethReserve);
            require(_amount >= cryptoDevTokenAmount, "Amount of tokens sent is less than the minimum tokens required");
            cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);
            liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }

    // @dev Returns the amount of 'Eth' and 'Crypto Dev' tokens to be returned to the user in exchange for LP tokens
    // @param _amount - The amount of LP tokens provided by the user
    function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
        require(_amount > 0, "Amount should be greater than zero");

        // The amount of Eth that would be sent back to the user is 
        // based on the ratio -> 
        // (Eth sent back to the user) / (current Eth reserve) = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // Then by some maths -> 
        // (Eth sent back to the user) = (current Eth reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // 
        // The amount of Crypto Dev token that would be sent back to the user is 
        // based on the ratio ->
        // (Crypto Dev sent back to the user) / (current Crypto Dev token reserve) = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // Then by some maths -> 
        // (Crypto Dev sent back to the user) = (current Crypto Dev token reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint256 ethReserve = address(this).balance;
        uint256 totalSupply = totalSupply();
        uint256 ethAmount = (ethReserve * _amount) / totalSupply;
        uint256 cryptoDevTokenAmount = (getReserve() * _amount) / totalSupply;

        // Burn the sent LP tokens from the user's wallet because they are already sent to remove liquidity
        // Transfer `ethAmount` of Eth from the contract to the user's wallet
        // Transfer `cryptoDevTokenAmount` of Crypto Dev tokens from the contract to the user's wallet
        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(ethAmount);
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
    }

    // @dev Calculates and returns the amount of 'Eth' and 'Crypto Dev' tokens to be returned to the user in the swap
    // We are required to follow the concept of 'XY = K' curve. Therefore, we need to make sure (x + Δx) * (y - Δy) = x * y
    // So the final formula is Δy = (y * Δx) / (x + Δx)
    // Δy in our case is `tokens to be received`
    // Δx = (_inputAmount * 99)/100, x = _inputReserve, y = _outputReserve
    //
    // @param _inputAmount - The amount of tokens the user is providing to be swapped.
    // @param _inputReserve - Reserve balance of the the token the user is swapping.
    // @param _outputReserve - Reserve balance of the token the user will be receiving. 
    function getAmountOfTokens(
        uint256 _inputAmount, 
        uint256 _inputReserve, 
        uint256 _outputReserve) public pure returns (uint256) {
        require(_inputReserve > 0 && _outputReserve > 0, "Invalid reserves");
        
        // We are charging a 1% fee for swapping
        uint256 inputAmountWithFee = (_inputAmount * 99) / 100; 
        uint256 numerator = _outputReserve * inputAmountWithFee;
        uint256 denominator = _inputReserve + inputAmountWithFee;
        return numerator / denominator;
    }

    // @dev Swaps 'Eth' for 'Crypto Dev' tokens
    // @param _minTokens - Minimum amount of 'Crypto Dev' tokens the user will receive 
    function ethToCryptoDevToken(uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();

        // Call the `getAmountOfTokens` to get the amount of Crypto Dev token that would be returned to the user after the swap
        // Notice that the `_inputReserve` we are sending is equal to
        // `address(this).balance - msg.value` instead of just `address(this).balance`
        // because `address(this).balance` already contains the `msg.value` user has sent in the given call
        // so we need to subtract it to get the actual input reserve
        uint256 tokensBought = getAmountOfTokens(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );

        require(tokensBought >= _minTokens, "Insufficient output amount");
        //Transfer 'Crypto Dev' tokens to the user
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
    }

    // @dev Swaps 'Crypto Dev' tokens for 'Eth'
    // @param _tokensSold - Amount of 'Crypto Dev' tokens the user is providing to be swapped
    // @param _minEth - Minimum amount of 'Eth' the user will receive  
    function cryptoDevTokenToEth(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        // Call getAmountOfTokens() to get the amount of 'Eth' that will be returned to the user after the swap
        uint256 ethBought = getAmountOfTokens(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );

        require(ethBought >= _minEth, "Insufficient output amount");
        // Transfer 'Crypto Dev' tokens from the user's address to the contract
        // Then send the 'ethBought' to the user from the contract
        ERC20(cryptoDevTokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );
        payable(msg.sender).transfer(ethBought);
    }
}