pragma solidity ^0.4.15;
import './CWBaseToken.sol';

contract DEFToken is CWBaseToken {

///////////////////////////////////////// VARIABLE INITIALIZATION /////////////////////////////////////////

    uint256 constant public DEF_UNIT = 10 ** 18;
    uint256 public totalSupply = 1 * (10**9) * DEF_UNIT;



///////////////////////////////////////// CONSTRUCTOR /////////////////////////////////////////

    function DEFToken()
    CWBaseToken("DEF Coin", "DEF", 18)
    {
    }

///////////////////////////////////////// ERC20 OVERRIDE /////////////////////////////////////////

    /**
        @dev send coins
        throws on any error rather than return a false flag to minimize user errors
        in addition to the standard checks, the function throws if transfers are disabled

        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, throws if it wasn't
    */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if (isTransferAllowed()) {
            assert(super.transfer(_to, _value));
            return true;
        }
        revert();        
    }

    /**
        @dev an account/contract attempts to get the coins
        throws on any error rather then return a false flag to minimize user errors
        in addition to the standard checks, the function throws if transfers are disabled

        @param _from    source address
        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, throws if it wasn't
    */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (isTransferAllowed()) {        
            assert(super.transferFrom(_from, _to, _value));
            return true;
        }
        revert();
    }
   
}
