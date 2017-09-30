// Payroll for chucaw's project! :D
// 29 Sep 2017, Singapore, Singapore
pragma solidity ^0.4.15;

import './PayrollInterface.sol';
import './ERC20Token.sol';
import './SafeMath.sol';
import './DateTimeUtils.sol';
import "./oraclizeAPI_0.4.sol";

contract CWPayroll is PayrollInterface, DateTimeUtils, usingOraclize {
    using SafeMath for uint256;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event newOraclizeQuery(string description);

    address public fOwner;          // this could be the HR, or finance controller...
    address public fScapeHatch;     // escape hatch
    uint256 fExchangeRate;          // exchange rate for the usd token
    uint8 fTokenDecimals;           // number of token decimals as provided by the Oracle
    uint256 fPayDayLastCall;        // store timestamp of lastcall 
    uint256 fDistributionLastCall;  // store timestamp of lastcall 



    modifier onlyBy(address _account) // allow either the owner, or the scapeHatch to call functions
    {
        require((_account == msg.sender)||(msg.sender == fScapeHatch));
        _;
    }

    modifier called6MonthsAgo() 
    {
        require((fDistributionLastCall == 0) || (now.sub(fDistributionLastCall) >= (6 * MONTH_IN_SECONDS)));
        _;
        fDistributionLastCall = now;
    }
    
    modifier called1MonthAgo()
    {
        require((fPayDayLastCall == 0) || (now.sub(fPayDayLastCall) >= (1 * MONTH_IN_SECONDS)));
        _;
        fPayDayLastCall = now;
    }
  
    function changeOwner(address _newOwner) public onlyBy(fOwner)
    {
        fOwner = _newOwner;
    }

    
    // Employee record
    struct Employee {
        uint employeeId;
        address employeeAddress;   // Employee's wallet for receiving salary 
        address[] allowedTokens;   // Employee's various wallet addresses for receiving various tokens
        uint256 salary;            // annual salary
    }
    
    uint256 fEmployeeId;           // current max employeeId
    
    function CWPayroll() public {
        fEmployeeId = 1;           // Set the first available employee ID
        fOwner = msg.sender;       // Sets the owner, probably a HR person
        fScapeHatch = 0x1234;      // allow this address for calling owner-only functions
        fDistributionLastCall = 0; // never called.
        fPayDayLastCall = 0;
        getExchangeRate();
    }
  
    // List of employees
    Employee[] private fEmployees;

  // assumes valid employeeId
  function getEmployeeIndex(uint256 employeeId) internal onlyBy(fOwner) returns (uint256) {
      for (uint256 i = 0; i < fEmployees.length; i++) {
          if (fEmployees[i].employeeId == employeeId)
            return i;
      }
  }

  
/* OWNER ONLY */
  // This assumes the number of allowedTokens do not change after the employee has been added.
  // if this happens, the employee has to be removed, and re-added, which would mean the employee has a new ID.
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) public onlyBy(fOwner) {
    fEmployees.push(Employee(fEmployeeId, accountAddress, allowedTokens, initialYearlyUSDSalary));
    fEmployeeId++;
  }

  
  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public onlyBy(fOwner) {
    for (uint256 i = 0; i < fEmployees.length; i++) {
        if (fEmployees[i].employeeId == employeeId) {
            fEmployees[i].salary = yearlyUSDSalary;
        }
    }
  }
  
  function removeEmployee(uint256 employeeId) public onlyBy(fOwner)
  {
    for (uint256 i = 0; i < fEmployees.length; i++) {
        if (fEmployees[i].employeeId == employeeId) {
          Employee storage lEmployee = fEmployees[employeeId];
          lEmployee.employeeId = 0; // remove employee ID
          lEmployee.salary = 0;     // remove salary
        }
    }
  }
  
// -----------------------------------------------------------------------------------------------------------------------------

  function () payable {
  }
  
  function addFunds() public payable {
    this.transfer(msg.value);  
  }
  
  function scapeHatch() {
    // Transfer funds out t the address in FScapeHatch...
    selfdestruct(fScapeHatch);
  }
  
  // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback

  function getEmployeeCount() onlyBy(fOwner) public constant returns (uint256) {
      uint256 lEmployeeCount = 0;
      for (uint256 i = 0; i < fEmployees.length; i++) {
          if (fEmployees[i].employeeId != 0) { // check employee has an ID
              lEmployeeCount++;
          }
      }
      return lEmployeeCount;
  }
  
  // Return all important info too
  function getEmployee(uint256 employeeId) public onlyBy(fOwner) constant returns (address employee) {
      uint256 lEmployeeIndex = getEmployeeIndex(employeeId);
      
      return fEmployees[lEmployeeIndex].employeeAddress;
  }

  // Monthly usd amount spent in salaries
  function calculatePayrollBurnrate() public onlyBy(fOwner) constant returns (uint256) {

      uint256 lBurnRate = 0; // burn rate in years...
      
      for (uint256 i = 0; i < fEmployees.length; i++) {
          if (fEmployees[i].employeeId != 0) {
              lBurnRate = lBurnRate.add(fEmployees[i].salary);
          }
      }
      
      return lBurnRate / 12;
  }
  
   // Days until the contract can run out of funds
  function calculatePayrollRunway() public onlyBy(fOwner) constant returns (uint256) {

      uint256 lFundsLeft = this.balance;
      uint256 lTotalBurnRate = calculatePayrollBurnrate();    // Annual salaries
      uint256 lMonthsLeft = lFundsLeft.div(lTotalBurnRate);
      uint256 lDaysLeft = lMonthsLeft.mul(30);
      
      return lDaysLeft;
  }

// -----------------------------------------------------------------------------------------------------------------------------
/* EMPLOYEE ONLY */
   // only callable once every 6 months
  function determineAllocation(address[] tokens, uint256[] distribution) 
    onlyBy(fOwner) 
    called6MonthsAgo() // ensures that it can only be called 6 months after the last call
  {
     uint256 lEmployeeCount = getEmployeeCount();
     uint256 lTotalEmployeeCount = lEmployeeCount;
     
     for (uint256 i=0; lEmployeeCount>0; i++) {
       if (fEmployees[i].salary != 0) { 

         uint256 ltokensLength = fEmployees[i].allowedTokens.length;
         // loop through the token addresses under each employee, and distribute equally
         for (uint256 j=0; i < ltokensLength; j++) {

           uint256 lDistribution = distribution[j];

           if (lDistribution == 0) continue;                           // if the distribution value is 0, then move on...

           uint256 lValue = lDistribution.div(lTotalEmployeeCount);    // allocate equally
           address lFromAddress = tokens[j];
           ERC20Token lToken  = ERC20Token(lFromAddress);              // This is the contract address of each token
           address lToAddress = fEmployees[i].allowedTokens[j];
           
           // transfer from the contract address to employee's token address. Assumes that no tokens were removed from distribution
           lToken.transferFrom(lFromAddress, lToAddress, lValue);   
           lEmployeeCount--;

         }
       }
     }
     
  }

  function payday() public 
    onlyBy(fOwner)  
    called1MonthAgo() // ensures that it can only be called 1 month after the last call
 {

     for (uint256 i = 0; i < fEmployees.length; i++) {

	 uint256 lMonthlySalary = fEmployees[i].salary.div(12); // salary is annual, so divide by 12 to get monthly salary.

	 // In Ethereum Blockchain, the total supply of a token is multiplied by 10^decimals, so do the same below
	 uint256 lMonthlySalaryInUSD = lMonthlySalary * fExchangeRate * uint256(10)**fTokenDecimals; // convert the monthly salary using the exchange rate and token decimals
	 address lEmployeeAddr = fEmployees[i].employeeAddress;
	 lEmployeeAddr.transfer(lMonthlySalaryInUSD); // transfer from this.balance into lEmployeeAddr the amount of lMonthlySalary

         Transfer(msg.sender, lEmployeeAddr, lMonthlySalaryInUSD); // notify all interested parties...
     }

  }

// -----------------------------------------------------------------------------------------------------------------------------

  /* ORACLE ONLY */
   // uses decimals from token
   // see also https://gist.github.com/masonforest/70d23ea3a8fe34ce12041c1cdd4e2920
   // callable either by the owner or by the Oracle
  function setExchangeRate(address token, uint256 usdExchangeRate) public onlyBy(oraclize_cbAddress()) {

    ERC20Token lToken = ERC20Token(token); // hardcast the address into an ERC20 token.
    fTokenDecimals = lToken.decimals();    // retrieve the token's decimals value

    // save the exchange rate
    fExchangeRate = usdExchangeRate;
  }
  
  
  function getExchangeRate() {
    oraclize_query(1*day, "URL", "");
  }

  
  function __callback(bytes32 myid, string result) {
    if (msg.sender != oraclize_cbAddress()) throw;

    // call setExchangeRate() using the data in the result string
    update();
  }  
  
  function update() payable {
    if (oraclize_getPrice("URL") > this.balance) {
       newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
       newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
       // need to fix the https://UrlToGetExchangeRate URL to the proper URL for the exchange rate
       oraclize_query(1*day, "URL", "json(https://UrlToGetExchangeRate).ETHUSD");
    }
  }

}
