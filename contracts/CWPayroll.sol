pragma solidity ^0.4.17;

import './PayrollInterface.sol';
import './ERC20Token.sol';
import './SafeMath.sol';
import './DateTimeUtils.sol';
import './oraclizeAPI_04.sol';

contract CWPayroll is PayrollInterface, DateTimeUtils, usingOraclize {
    using SafeMath for uint256;
    
    
    bool internal isDebug;

    // Employee record
    struct Employee {
        uint employeeId;
        address employeeAddress;   // Employee's wallet for receiving salary 
        address[] allowedTokens;   // Employee's various wallet addresses for receiving various tokens
        uint256 salary;            // annual salary
    }
    // List of employees
    Employee[] private employees;
    uint256 employeeId;           // current max employeeId

    mapping (address => mapping (address => uint)) allowed;
    address fscapeHatch;     // escape hatch
    address owner;
    uint256 usdExchangeRate;        // exchange rate for the usd token
    uint8 usdTokenDecimals;         // number of token decimals as provided by the Oracle
    uint256 payDayLastCall;         // store timestamp of lastcall 
    uint256 distributionLastCall;   // store timestamp of lastcall 
    mapping(bytes32=>bool) validIds;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event newOraclizeQuery(string description);
    event __Log(string msg);
    event Approval(address indexed owner, address indexed spender, uint value);


    modifier onlyScapeHatch() {
      require(msg.sender == fscapeHatch);
      _;
    }
    
    // allow either the owner, or the scapeHatch to call functions
    modifier onlyOwnerOrCreator() {
        require(msg.sender == fscapeHatch || msg.sender == owner);
        _;
    }

    modifier called6MonthsAgo() {
        require(distributionLastCall == 0 || now.sub(distributionLastCall) >= (6 * MONTH_IN_SECONDS));
        _;
        distributionLastCall = now;
    }
    
    modifier called1MonthAgo() {
        require((payDayLastCall == 0) || (now.sub(payDayLastCall) >= (1 * MONTH_IN_SECONDS)));
        _;
        payDayLastCall = now;
    }

    function enableDebug() public onlyOwnerOrCreator {
      isDebug = true;
    }

    function disableDebug() public onlyOwnerOrCreator {
      isDebug = false;
    }

    function Log(string msg) public {
      if (isDebug)
        __Log(msg);
    }

    function getOwner() external returns (address) {
      return owner;
    }
    
    function changeOwner(address _newOwner) public onlyOwnerOrCreator {
        owner = _newOwner;
        Log("Ownership changed");      
    }
  
    
    function CWPayroll() public {
        // Set the first available employee ID
        employeeId           = 1;           
        
        // Allow escape hatch for the contract creator
        fscapeHatch           = msg.sender;
        
        // make the contract creator the default owner
        owner                = msg.sender;

        resetCalledCounters(); 
    }
    
    
    function () public payable {
    }
  

    function scapeHatch() onlyScapeHatch public {
      // Transfer funds out to the address in scapeHatch...
      selfdestruct(fscapeHatch);
    }

    // assumes valid employeeId, returns index to the employee array
    function getEmployeeIndex(uint256 employeeId) internal onlyOwnerOrCreator returns (uint256) {
        for (uint256 i = 0; i < employees.length; i++) {
          if (employees[i].employeeId == employeeId) {
            return i;
          }
        }
    }
  
    /* OWNER ONLY */
    // This assumes the number of allowedTokens do not change after the employee has been added.
    // if this happens, the employee has to be removed, and re-added, which would mean the employee has a new ID.
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) public onlyOwnerOrCreator {
      employees.push(Employee(employeeId, accountAddress, allowedTokens, initialYearlyUSDSalary));
      employeeId++;
    }
  
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public onlyOwnerOrCreator {
      for (uint256 i = 0; i < employees.length; i++) {
          if (employees[i].employeeId == employeeId) {
              employees[i].salary = yearlyUSDSalary;
          }
      }
    }
  
    function removeEmployee(uint256 employeeId) public onlyOwnerOrCreator {
      for (uint256 i = 0; i < employees.length; i++) {
          if (employees[i].employeeId == employeeId) {
            Employee storage lEmployee = employees[employeeId];
            lEmployee.employeeId = 0; // remove employee ID
            lEmployee.salary = 0;     // remove salary
          }
      }
    }
  
    function getEmployeeCount() onlyOwnerOrCreator public constant returns (uint256) {
        uint256 lEmployeeCount = 0;
        for (uint256 i = 0; i < employees.length; i++) {
            if (employees[i].employeeId != 0) { // check employee has an ID
                lEmployeeCount++;
            }
        }
        Log('returning employeeCount');
        return lEmployeeCount;
    }
  
    // Return all important info too
    function getEmployee(uint256 _employeeId) onlyOwnerOrCreator public constant returns (address employee) {
        uint256 lEmployeeIndex = getEmployeeIndex(_employeeId);
        
        return employees[lEmployeeIndex].employeeAddress;
    }

// -----------------------------------------------------------------------------------------------------------------------------

 
  // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback

    function approve(address _spender, uint _value) public {
      //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
      assert(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));
      allowed[msg.sender][_spender] = _value;
      Approval(msg.sender, _spender, _value);
    }

    function addFunds() public payable {
    }


    // Monthly usd amount spent in salaries
    function calculatePayrollBurnrate() public onlyOwnerOrCreator constant returns (uint256) {

        uint256 lBurnRate = 0; // burn rate in years...
        
        for (uint256 i = 0; i < employees.length; i++) {
            if (employees[i].employeeId != 0) {
                lBurnRate = lBurnRate.add(employees[i].salary);
            }
        }
        
        return lBurnRate / 12;
    }
  
   // Days until the contract can run out of funds
  function calculatePayrollRunway() public onlyOwnerOrCreator constant returns (uint256) {

      uint256 lFundsLeft = this.balance;
      uint256 lTotalBurnRate = calculatePayrollBurnrate();    // Annual salaries
      uint256 lMonthsLeft = lFundsLeft.div(lTotalBurnRate);
      uint256 lDaysLeft = lMonthsLeft.mul(30);
      
      return lDaysLeft;
  }

// -----------------------------------------------------------------------------------------------------------------------------

   /* EMPLOYEE ONLY */
   // only callable once every 6 months
   // ensures that it can only be called 6 months after the last call
  function determineAllocation(address[] tokens, uint256[] distribution) public onlyOwnerOrCreator called6MonthsAgo { 
     uint256 lEmployeeCount = getEmployeeCount();
     uint256 lTotalEmployeeCount = lEmployeeCount;
     
     for (uint256 i=0; lEmployeeCount>0; i++) {
       if (employees[i].salary != 0) { 

         uint256 ltokensLength = employees[i].allowedTokens.length;
         // loop through the token addresses under each employee, and distribute equally
         for (uint256 j=0; i < ltokensLength; j++) {
           uint256 lDistribution = distribution[j];

           if (lDistribution == 0) 
             continue;                           // if the distribution value is 0, then move on...

           uint256 lValue = lDistribution.div(lTotalEmployeeCount);    // allocate equally
           address lFromAddress = tokens[j];
           ERC20Token lToken  = ERC20Token(lFromAddress);              // This is the contract address of each token
           address lToAddress = employees[i].allowedTokens[j];
           
           // transfer from the contract address to employee's token address. Assumes that no tokens were removed from distribution
           lToken.transferFrom(msg.sender, lToAddress, lValue);   
           lEmployeeCount--;
           Log('allocation determined!');  
         }
       }
     }
     
  }

  function payday() public onlyOwnerOrCreator called1MonthAgo() // ensures that it can only be called 1 month after the last call
  {
     for (uint256 i = 0; i < employees.length; i++) {

         uint256 lMonthlySalary = employees[i].salary.div(12); // salary is annual, so divide by 12 to get monthly salary.

  // In Ethereum Blockchain, the total supply of a token is multiplied by 10^decimals, so do the same below
         uint256 lMonthlySalaryInUSD = lMonthlySalary * usdExchangeRate * uint256(10)**usdTokenDecimals; // convert the monthly salary using the exchange rate and token decimals
         address lEmployeeAddr = employees[i].employeeAddress;
         lEmployeeAddr.transfer(lMonthlySalaryInUSD); // transfer from this.balance into lEmployeeAddr the amount of lMonthlySalary

         Transfer(msg.sender, lEmployeeAddr, lMonthlySalaryInUSD); // notify all interested parties...
     }
  }

// -----------------------------------------------------------------------------------------------------------------------------

   /* ORACLE ONLY */
   // uses decimals from token
   // see also https://gist.github.com/masonforest/70d23ea3a8fe34ce12041c1cdd4e2920
   // callable either by the owner or by the Oracle
    function setExchangeRate(address token, uint256 usdExchangeRate) public onlyOwnerOrCreator {
      if (msg.sender != oraclize_cbAddress())
        return;
      IERC20Token lToken = IERC20Token(token); // hardcast the address into an ERC20 token.
      usdTokenDecimals = lToken.decimals();    // retrieve the token's decimals value

      // save the exchange rate
      usdExchangeRate = usdExchangeRate;
    }
  
    function startExchangeRateUpdate() public payable onlyOwnerOrCreator {
      getExchangeRate();                   // needs payment
    }

    function getExchangeData(uint timestamp) payable {
      // oraclize_query returns a unique query id (UID) that identifies this specfic request.
      bytes32 queryId = oraclize_query(timestamp, "URL", "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD");
      validIds[queryId] = true; // map this UID.
    }
    
    function getExchangeRate() payable onlyOwnerOrCreator {
      getExchangeData(0); // get data immediately
    }

  
    function __callback(bytes32 myid, string result) public {
      // reject invalid UID, or non-Oracle caller
      if ((!validIds[myid]) || (msg.sender != oraclize_cbAddress())) 
        revert;

      delete validIds[myid];

      // ****** PLACE CALL TO setExchangeRate BELOW ******************************************************************************
      // call setExchangeRate() using the data in the result string **************************************************************

      update(); // trigger update to run 1 day later

    }
    
    function update() internal {
      if (msg.sender != oraclize_cbAddress()) 
        revert;

      if (oraclize_getPrice("URL") > this.balance) {
        newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
      } else {
        newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        getExchangeData(1*day);
      }

    }
  
  
    function resetCalledCounters() internal onlyOwnerOrCreator {
      payDayLastCall       = 0;  // reset timestamp of lastcall 
      distributionLastCall = 0;  // reset timestamp of lastcall 
    }
    
}
