// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";



contract MultiTransferHelper {


    event MultiValueTransfer(address from,address payable[] tos,uint[] value,string data);
    event MultiValueTransferErc20(address contractAddr,address from,address[] tos,uint[] value,string data);
    event MultiValueTransferErc721(address contractAddr, address from,address[] tos,uint[] tokenIds,string data);

      
    

    function transferManyValue(address payable[] memory addrs , uint256[] memory values,uint256 len,uint256 _totalValue,string memory data) payable public {
      require(len == addrs.length && len == values.length && len <= 100);
      require( _totalValue == msg.value );
      uint256 totalValue = 0; 
      for (uint i = 0;i < len ; i++){
        totalValue += values[i];
        addrs[i].transfer(values[i]);
      }
//      emit MultiValueTransfer(address(this),addrs,values,data);
      require( totalValue  == _totalValue);
    }


    function transferManyErc20Value(address tokenAddr,address [] memory addrs , uint256[] memory values,uint256 len,uint256 _totalValue,string memory data) public {
      require(len == addrs.length && len == values.length && len <= 100);
      uint256 totalValue = 0; 
      for (uint i = 0;i < len ; i++){
        totalValue += values[i];
        IERC20(tokenAddr).transferFrom(msg.sender,addrs[i] ,values[i]);
      }
    //  emit MultiValueTransferErc20(tokenAddr,msg.sender,addrs,values,data);
      require( totalValue  == _totalValue);
    }


    function transferManyErc721Value(address nftAddr,address [] memory addrs , uint256[] memory tokenIds,uint256 len,string memory data) public {
      require(len == addrs.length && len == tokenIds.length && len <= 100);

      for (uint i = 0;i < len ; i++){
        IERC721(nftAddr).transferFrom(msg.sender,addrs[i] ,tokenIds[i]);
      }
     // emit MultiValueTransferErc721(nftAddr,msg.sender,addrs,tokenIds,data);
    }



}
