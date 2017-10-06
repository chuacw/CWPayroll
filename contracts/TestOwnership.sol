pragma solidity ^0.4.15;

contract TestOwnership {
    
    address fscapeHatch;     // escape hatch
    address internal owner;

    event __Log(string msg);


    modifier onlyScapeHatch() {
      require(msg.sender == fscapeHatch);
      _;
    }
    
    // allow either the owner, or the scapeHatch to call functions
    modifier onlyOwnerOrCreator() {
        require(msg.sender == fscapeHatch || msg.sender == owner);
        _;
    }

    function Log(string msg) public {
       __Log(msg); // removed conditional check for now and trigger the event directly
    }

    function getOwner() external returns (address) {
      Log("Ownership query");
      return owner;
    }
    
    function changeOwner(address _newOwner) external onlyOwnerOrCreator {
        owner = _newOwner;
        Log("Ownership changed");      
    }
  
    function TestOwnership() public {
        fscapeHatch          = msg.sender;
        owner                = msg.sender;
        Log("TestOwnership created...");
    }
    
}
