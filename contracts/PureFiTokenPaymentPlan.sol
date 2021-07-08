pragma solidity ^0.8.6;


import "../openzeppelin-contracts-master/contracts/token/ERC20/IERC20.sol";
import "../openzeppelin-contracts-master/contracts/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin-contracts-master/contracts/access/Ownable.sol";


contract PureFiTokenPaymentPlan is Ownable {

  using SafeERC20 for IERC20;

  struct PaymentPlan{
    uint64[] unlockDateShift; //timestamp shift of the unlock date; I.e. unlock date = unlockDateShift + startDate
    uint16[] unlockPercent; //unlock percents multiplied by 100;
  }

  struct Vesting{
    uint8 paymentPlan; //payment plan ID
    uint64 startDate; //payment plan initiation date. Can be 0 if PaymentPlan refers to exact unlock timestamps.
    uint256 totalAmount; //total amount of tokens vested for a person
    uint256 withdrawnAmount; //amount withdrawn by user
  }

  PaymentPlan[] internal paymentPlans;
  mapping (address => Vesting) internal vestedTokens;

  IERC20 internal token;
  uint64 public startDate; //timestamp this contracts start operations at. Claiming tokens is not available before this date
  uint256 public totalVestedAmount; // total amount of vested tokens under this contract control.

  event Withdrawal(address indexed who, uint256 amount);
  event PaymentPlanAdded(uint256 index);
  event TokensVested(address indexed beneficiary, uint8 paymentPlan, uint64 startDate, uint256 amount);
  
  constructor (
    address _token,
    uint64 _start
  )
  {
    require(_token != address(0),"incorrect token address");
    require(_start > block.timestamp, "incorrect start time");
    token = IERC20(_token);
    startDate = _start;
  }


  function addPaymentPlan(uint64[] memory _ts, uint16[] memory _percents) public onlyOwner(){
    require(_ts.length == _percents.length,"array length doesn't match");
    uint16 totalPercent = 0;
    uint16 prevPercent = 0;
    uint64 prevDate = 0;
    for(uint i = 0; i < _ts.length; i++){
      require (prevPercent <= _percents[i], "Incorrect percent value");
      require (prevDate <= _ts[i], "Incorrect unlock date value");
      prevPercent = _percents[i];
      prevDate = _ts[i];
      totalPercent += _percents[i];
    }
    require(totalPercent == 10000, "Total percent is not 100%");
    
    paymentPlans.push(PaymentPlan(_ts, _percents));
    emit PaymentPlanAdded(paymentPlans.length - 1);
  }

  function vestTokens(uint8 _paymentPlan, uint64 _startDate, uint256 _amount, address _beneficiary) public onlyOwner {
    require(vestedTokens[_beneficiary].totalAmount == 0, "This address already has vested tokens");
    require(paymentPlans.length > _paymentPlan, "Incorrect payment plan index");
    require(_amount > 0, "Can't vest 0 tokens");
    require(token.balanceOf(address(this)) >= totalVestedAmount + _amount, "Not enough tokens for this vesting plan");
    vestedTokens[_beneficiary] = Vesting(_paymentPlan, _startDate, _amount, 0);
    totalVestedAmount += _amount;
    emit TokensVested(_beneficiary, _paymentPlan, _startDate, _amount);
  }

  function withdraw(uint256 _amount) public {
    require(vestedTokens[msg.sender].totalAmount > 0,"No tokens vested for this address");
    (, uint256 available) = withdrawableAmount(msg.sender);
    require(_amount <= available, "Amount exeeded current withdrawable amount");
    require(available > 0, "Nothing to withdraw");
    vestedTokens[msg.sender].withdrawnAmount += _amount;
    totalVestedAmount -= _amount;
    token.safeTransfer(msg.sender, _amount);
    emit Withdrawal(msg.sender, _amount);
  }

  function withdrawableAmount(address _beneficiary) public view returns (uint64, uint256) {
    require(vestedTokens[_beneficiary].totalAmount > 0,"No tokens vested for this address");
    uint16 percentLocked = 0;
    uint64 paymentPlanStartDate = vestedTokens[_beneficiary].startDate;
    uint256 index = paymentPlans[vestedTokens[_beneficiary].paymentPlan].unlockPercent.length;
    uint64 nextUnlockDate = 0;
    while (index > 0 && uint64(block.timestamp) < paymentPlanStartDate + paymentPlans[vestedTokens[_beneficiary].paymentPlan].unlockDateShift[index-1]) {
      index--;
      nextUnlockDate = paymentPlanStartDate + paymentPlans[vestedTokens[_beneficiary].paymentPlan].unlockDateShift[index];
      percentLocked += paymentPlans[vestedTokens[_beneficiary].paymentPlan].unlockPercent[index];
      
    }
    uint256 amountLocked = vestedTokens[_beneficiary].totalAmount*percentLocked/10000;
    uint256 remaining = vestedTokens[_beneficiary].totalAmount - vestedTokens[_beneficiary].withdrawnAmount;
    uint256 available = 0;
    if (remaining > amountLocked){
      available = remaining - amountLocked;
    } else {
      //overflow
      available = 0;
    }

    return (nextUnlockDate, available);
  }

  function vestingData(address _beneficiary) public view returns (uint8, uint64, uint64, uint256, uint256, uint256) {
    (uint64 nextUnlockDate, uint256 available) = withdrawableAmount(_beneficiary);
    return (vestedTokens[_beneficiary].paymentPlan, vestedTokens[_beneficiary].startDate, nextUnlockDate, vestedTokens[_beneficiary].totalAmount, vestedTokens[_beneficiary].withdrawnAmount, available);
  }

  function paymentPlanLength(uint256 _paymentPlan) public view returns(uint256){
    return paymentPlans[_paymentPlan].unlockPercent.length;
  }

  function paymentPlanData(uint256 _paymentPlan, uint256 _index) public view returns (uint64, uint16){
    return (paymentPlans[_paymentPlan].unlockDateShift[_index], paymentPlans[_paymentPlan].unlockPercent[_index]);
  }
}
