pragma solidity ^0.4.15;

contract Debuggable {
  event __Log(string logmsg);
  
  enum EthereumNetwork { enMainNet, enRopsten, enKovan, enRinkeby, enBridge, enEtherCampIde, enSolidityBrowser }
  
  bool isDebug = false;
  
  function enableDebug() {
    isDebug = true;
  }
  
  function disableDebug() {
    isDebug = false;
  }
  
  function Log(string log) {
    if (isDebug)
      __Log(log);
  }

  function getCodeSize(address _addr) constant internal returns(uint _size) {
      assembly {
          _size := extcodesize(_addr)
      }
  }

 // Uses the Oracle to determine which network this code is running on
 function getNetwork() constant public returns(EthereumNetwork) {
   if (getCodeSize(0x1d3B2638a7cC9f2CB3D298A3DA7a90B67E5506ed)>0){ //mainnet
       return EthereumNetwork.enMainNet;
   }
   if (getCodeSize(0xc03A2615D5efaf5F49F60B7BB6583eaec212fdf1)>0){ //ropsten testnet
       return EthereumNetwork.enRopsten;
   }
   if (getCodeSize(0xB7A07BcF2Ba2f2703b24C0691b5278999C59AC7e)>0){ //kovan testnet
       return EthereumNetwork.enKovan;
   }
   if (getCodeSize(0x146500cfd35B22E4A392Fe0aDc06De1a1368Ed48)>0){ //rinkeby testnet
       return EthereumNetwork.enRinkeby;
   }
   if (getCodeSize(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475)>0){ //ethereum-bridge
       return EthereumNetwork.enBridge;
   }
   if (getCodeSize(0x20e12A1F859B3FeaE5Fb2A0A32C18F5a65555bBF)>0){ //ether.camp ide
       return EthereumNetwork.enEtherCampIde;
   }
   if (getCodeSize(0x51efaF4c8B3C9AfBD5aB9F4bbC82784Ab6ef8fAA)>0){ //browser-solidity
       return EthereumNetwork.enSolidityBrowser;
   }
   throw;
 }
 
 
}