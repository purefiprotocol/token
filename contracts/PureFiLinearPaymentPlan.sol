pragma solidity ^0.8.6;


import "./PureFiPaymentPlan.sol";

contract PureFiTokenLinearPaymentPlan is PureFiPaymentPlan {

  struct PaymentPlan{
    uint64 cliff;
    uint64 period;
    uint64 initiallyUnlockedPercent;
    uint64 periodPayoutPercent; 
  }

  PaymentPlan[] internal paymentPlans;
  
  uint256 public constant PERCENT_100 = 100_000000; // 100% with extra denominator

  function addPaymentPlan(uint64 _cliff, uint64 _period, uint64 _initialPayoutPercent, uint64 _periodPayoutPercent) public onlyOwner whenNotPaused {
    require(_periodPayoutPercent > 0, "Incorrect _periodPayoutPercent");
    require(_period > 0, "Incorrect _period");
    paymentPlans.push(PaymentPlan(_cliff, _period, _initialPayoutPercent, _periodPayoutPercent));

    emit PaymentPlanAdded(paymentPlans.length - 1);
  }

  function withdrawableAmount(address _beneficiary) public override view returns (uint64, uint256) {
    require(vestedTokens[_beneficiary].totalAmount > 0,"No tokens vested for this address");
    uint64 paymentPlanStartDate = vestedTokens[_beneficiary].startDate;
    uint64 userCliff = paymentPlans[vestedTokens[_beneficiary].paymentPlan].cliff;

    uint256 unlockedPercent;
    uint64 nextUnlockDate;
    if(block.timestamp < paymentPlanStartDate){
      unlockedPercent = 0;
      nextUnlockDate = paymentPlanStartDate;
    } else if(block.timestamp >= paymentPlanStartDate && block.timestamp < paymentPlanStartDate + userCliff){
      unlockedPercent = paymentPlans[vestedTokens[_beneficiary].paymentPlan].initiallyUnlockedPercent;
      nextUnlockDate = paymentPlanStartDate + userCliff;
    } else {
      unlockedPercent = paymentPlans[vestedTokens[_beneficiary].paymentPlan].initiallyUnlockedPercent;
      uint256 multiplier = (block.timestamp - userCliff - paymentPlanStartDate) / paymentPlans[vestedTokens[_beneficiary].paymentPlan].period;
      unlockedPercent += multiplier * paymentPlans[vestedTokens[_beneficiary].paymentPlan].periodPayoutPercent; 
      if(unlockedPercent > PERCENT_100){
        unlockedPercent = PERCENT_100;
        nextUnlockDate = 0;
      }else{
        nextUnlockDate = paymentPlanStartDate + userCliff + uint64(multiplier + 1) * paymentPlans[vestedTokens[_beneficiary].paymentPlan].period;
      }
    }

    uint256 amountUnlocked = vestedTokens[_beneficiary].totalAmount * unlockedPercent / PERCENT_100;

    uint256 available = 0;
    if (vestedTokens[_beneficiary].withdrawnAmount < amountUnlocked){
      available = amountUnlocked - vestedTokens[_beneficiary].withdrawnAmount;
    } else {
      //overflow
      available = 0;
    }

    return (nextUnlockDate, available);
  }

  function paymentPlanData(uint256 _paymentPlan) public view returns (uint64, uint64, uint64, uint64){
    return (paymentPlans[_paymentPlan].cliff,
            paymentPlans[_paymentPlan].period,
            paymentPlans[_paymentPlan].initiallyUnlockedPercent,
            paymentPlans[_paymentPlan].periodPayoutPercent);
  }

  function _isPaymentPlanExists(uint8 _id) internal override view returns (bool){
    return (_id < paymentPlans.length);
  }
}
