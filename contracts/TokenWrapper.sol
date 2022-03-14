// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


// TokenWrapper used  to mutiply src token with more decimals
contract TokenWrapper is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;



    ERC20 public immutable targetToken;
    uint8 public immutable targetDecimals;
    uint256 public immutable multiple ;

    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        ERC20 _targetToken
    ) public ERC20(name,symbol){
        require(address(_targetToken) != address(0));
        uint8 _targetDecimals = _targetToken.decimals();
        require(decimals > _targetDecimals);
        _setupDecimals(decimals);

        //set immutable value
        multiple = uint256(10) ** (decimals-_targetDecimals);
        targetDecimals = _targetDecimals;
        targetToken = _targetToken;

    }


    //wrap target Token to got this token
    function wrap(uint256 targetAmount) external{
        targetToken.safeTransferFrom(msg.sender,address(this),targetAmount);
        uint256 thisAmount = targetAmount.mul(multiple);
        _mint(msg.sender, thisAmount);
        emit Deposit(msg.sender,targetAmount);
    }

    //burn this token to got back target token
    function unwrap(uint256 thisAmount) external{
        _burn(msg.sender,thisAmount);
        uint256 targetAmount = thisAmount.div(multiple);
        targetToken.safeTransfer(msg.sender,targetAmount);
        emit Withdrawal(msg.sender,targetAmount);
    }
    
}
