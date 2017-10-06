// chuacw, Singapore, 6 Oct 2017

const TestOwnership = artifacts.require('../contracts/TestOwnership.sol');
const { assertInvalidOpcode } = require('./helpers/assertThrow')

contract("TestOwnership", accounts => {

  let cwpayroll        = {};
  let account_main     = accounts[0];
  let account_finance  = accounts[1];
  let account_outsider = accounts[2];

  let account_creator  = account_main;
  let events;
  
  console.log(accounts);
  
  beforeEach(() => {
    return TestOwnership.new({from: account_creator})
     .then(instance => {

       events = instance.allEvents();
       events.watch(function(error, event){
           if (error) {
               console.log("Error: " + error);
           } else {
               console.log(event.event + ": " + JSON.stringify(event.args));
           }
       });

       cwpayroll = instance;
       return instance;
     });
  })
  
  afterEach(() => {
    
    cwpayroll = {}
  })
  

  it("Test1 - owner should be creator", () => {
    // defines the tasks
    task1 = () => { 
      if (cwpayroll.getOwner()) 
        return cwpayroll.getOwner.call();
    };
    task2 = newOwner => { assert.equal(newOwner, account_creator); }
    
    task1().then(task1Result => task2(task1Result));
  })
  

 
  it("Test2 - passes when changing ownership from an authorized account", () => {
    // defines the tasks
    let newaccount = account_outsider; // allows centralized changing of the new account to change to
    task1 = () => { 
      if (cwpayroll.changeOwner(newaccount, {from: account_creator})) 
        return cwpayroll.changeOwner.call(newaccount, {from: account_creator}); 
    };
    
    task2 = () => { 
      if (cwpayroll.getOwner())
        return cwpayroll.getOwner.call();
    };
    
    task3 = newOwner => {
      assert.equal(newOwner, newaccount); 
    };
    
    // executes the tasks
    // this makes tasks easier to read and debug.
    return task1().then(task2().then(task2Result => task3(task2Result)));
  })
  
  

  it("Test3 - fails when changing ownership from an unauthorized account", async () => {
    return assertInvalidOpcode(async () => {
      await cwpayroll.changeOwner.call(account_outsider, {from: account_outsider})
    })
  })
  

})
