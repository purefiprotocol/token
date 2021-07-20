pragma solidity ^0.8.6;

import "./PureFiPaymentPlan.sol";

contract PureFiFixedDatePaymentPlan is PureFiPaymentPlan {

  struct PaymentPlan{
    uint64[] unlockDateShift; //timestamp shift of the unlock date; I.e. unlock date = unlockDateShift + startDate
    uint16[] unlockPercent; //unlock percents multiplied by 100;
  }

  PaymentPlan[] internal paymentPlans;

  uint256 public constant PERCENT_100 = 100_00; // 100% with extra denominator

  function addPaymentPlan(uint64[] memory _ts, uint16[] memory _percents) public onlyOwner whenNotPaused{
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
    require(totalPercent == PERCENT_100, "Total percent is not 100%");
    
    paymentPlans.push(PaymentPlan(_ts, _percents));
    emit PaymentPlanAdded(paymentPlans.length - 1);
  }

  function withdrawableAmount(address _beneficiary) public override view returns (uint64, uint256) {
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
    uint256 amountLocked = vestedTokens[_beneficiary].totalAmount*percentLocked / PERCENT_100;
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

  function paymentPlanLength(uint256 _paymentPlan) public view returns(uint256){
    return paymentPlans[_paymentPlan].unlockPercent.length;
  }

  function paymentPlanData(uint256 _paymentPlan, uint256 _index) public view returns (uint64, uint16){
    return (paymentPlans[_paymentPlan].unlockDateShift[_index], paymentPlans[_paymentPlan].unlockPercent[_index]);
  }

  function _isPaymentPlanExists(uint8 _id) internal override view returns (bool){
    return (_id < paymentPlans.length);
  }
}
