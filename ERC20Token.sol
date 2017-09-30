pragma solidity ^0.4.15;

contract ERC20Token  { // assumes that this imports the complete data....
    string public standard = 'Token 0.1';
    string public name = '';
    string public symbol = '';
    uint8 public decimals = 0;
    uint256 public totalSupply = 0;
    
    function transferFrom(address from, address to, uint value);
}
