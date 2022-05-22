// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Inheriting from ERC20 so that to kepp track of LP token
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Exchange is ERC20 {

    address public cryptoDevTokenAddress;

    constructor(address _CryptoDevToken) ERC20("CryptoDev LP Token", "CDLP") {
        require(_CryptoDevToken != address(0), "Token address passed is null address");
        cryptoDevTokenAddress = _CryptoDevToken;
    }

    /**
     * @dev returns the reserve of Crypto Dev Token
     */
    function getReserve() public view returns(uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    /**
     * @dev Adds liquidity to the exchange.
     */
    function addLiquidity(uint256 _tokenAmount) public payable returns (uint) {
        // If the token reserve is 0, it means it is the first time someone is adding the liquidity
        // So we dont need to check for the reation
        /*
        If the reserve is empty, intake any user supplied value for
        `Ether` and `Crypto Dev` tokens because there is no ratio currently
        */
        uint256 LPToBeMinted;
        if (getReserve() == 0) {
            // Transfer the `cryptoDevToken` from the user's account to the contract
            ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);
            LPToBeMinted = address(this).balance;
            _mint(msg.sender, LPToBeMinted);
        } else {
            // If not 0, then we have tomake sure that the token amount to be added is in ration of reserves of pair to avoid impact on price
            /*
            If the reserve is not empty, intake any user supplied value for
            `Ether` and determine according to the ratio how many `Crypto Dev` tokens
            need to be supplied to prevent any large price impacts because of the additional
            liquidity
            */
            // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user
            // in the current `addLiquidity` call
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 proportionalRatio = (msg.value * tokenReserve) / ethReserve;
            require(_tokenAmount >= proportionalRatio, "Added amount not in proper ration");
            ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), proportionalRatio);
            // On successfull adding of funds, we have to give some CDLP to liquidity provider
            // The amount of LP tokens that get minted to the user are propotional to the Eth supplied by the user
            // transfer only (cryptoDevTokenAmount user can add) amount of `Crypto Dev tokens` from users account
            // to the contract
            uint256 LPSupply = totalSupply();
            LPToBeMinted = (msg.value * LPSupply) / ethReserve;
            _mint(msg.sender, LPToBeMinted);
        }
        return LPToBeMinted;
    }


    /** 
    * @dev Returns the amount Eth/Crypto Dev tokens that would be returned to the user
    * in the swap
    */
    function removeLiquidity(uint _amount) public returns (uint, uint) {
        // User would get the Toekn back alonf with eth relative to it's LPToken holding
        // total LP supply --> ethReserve
        // amount of LPToken user wants to withdraw --> amt of eth user would get
        // Amount of cryptoDevToken to be transfeered to uder is
        // tottalsupply of Lp --> CryptoDevTokenreserve
        // amount of LP user withdraws --> Amount of cryptodev token to be returned
        require(_amount > 0, "Enter proper amount");
        require(balanceOf(msg.sender) >= _amount, "You don't have this much amount");
        uint256 totalLPSupply = totalSupply();
        uint256 ethReserve = address(this).balance;
        uint256 cryptoDevReserve = getReserve();
        uint256 ethToBeTransferred = (_amount * ethReserve) / totalLPSupply;
        uint256 cryptoDevToBeTransferred = (_amount * cryptoDevReserve) / totalLPSupply;
        _burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: ethToBeTransferred}("");
        require(success, "Transfer failed");
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevToBeTransferred);
        return (ethToBeTransferred, cryptoDevToBeTransferred);
    }

    /**
    * @dev Returns the amount Eth/Crypto Dev tokens that would be returned to the user
    * in the swap
    */
    function getAmountOfTokens(uint256 inputAmount, uint256 inputReserve, uint256 outpurReseve) public pure returns (uint256) {
        require(inputReserve > 0 && outpurReseve > 0, "Invalid Reserves");
        // We will charge 1% as fee
        // Input amount with fees = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100
        uint256 outputAmount = (outpurReseve * ((inputAmount * 99) / 100)) / (inputReserve + ((inputAmount * 99) / 100));
        return outputAmount;
    }

    function ethToCryptoDevToken(uint _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 tokenBought = getAmountOfTokens(msg.value, address(this).balance - msg.value, tokenReserve);
        require(tokenBought >= _minTokens, "Amount of ethereum is not sufficient");
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokenBought);
    }

    function cryptoDevTokenToEth(uint _tokenSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;
        uint256 ethToBeGiven = getAmountOfTokens(
            _tokenSold,
            tokenReserve,
            ethReserve
        );
        require(ethToBeGiven >= _minEth, "Insufficient funds");
        ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), _tokenSold);
        payable(msg.sender).transfer(ethToBeGiven);
    }

}