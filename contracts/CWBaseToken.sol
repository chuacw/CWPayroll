pragma solidity ^0.4.15;
import './ERC20Token.sol';

contract CWBaseToken is ERC20Token {


  function CWBaseToken(string _name, string _symbol, uint8 _decimals)
  ERC20Token(_name, _symbol, _decimals)
  {
  }

  // some condition to allow transfer
  function isTransferAllowed() internal constant returns(bool) {
    return true;
  }

}