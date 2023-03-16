const PureFiLinearPaymentPlan = artifacts.require('PureFiLinearPaymentPlan');
const PureFiLinearPaymentPlan2 = artifacts.require('PureFiLinearPaymentPlan2');
const PProxyAdmin = artifacts.require('PProxyAdmin');

module.exports = async function(callback) {
    
    let owner = "0xcE14bda2d2BceC5247C97B65DBE6e6E570c4Bb6D";
    // web3.eth.sendTransaction({
    //     from:'0x22724aBDB612F65814ec7990b495d0DdA8B078BF',
    //     to: owner,
    //     value: web3.utils.toWei("10.0", "ether")
    // })
    // console.log(await web3.eth.getBalance(owner))
    // console.log(await PureFiLinearPaymentPlan2.new.estimateGas())
    let logic = await PureFiLinearPaymentPlan2.new( { from: owner } );
    let admin = await PProxyAdmin.at("0x3f11558964F51Db1AF18825D0f4F8D7FC8bb6ac7");
    let proxy = "0xF9da2dE9E04561f69AB770a846eE7DDCfc2c53F6";
    let pureFiLinearPaymentPlan = await PureFiLinearPaymentPlan.at(proxy);

    let source = "0x96517A60De5Cb015513152cb4A8DAc965f661E0C";
    let destination = "0xcE14bda2d2BceC5247C97B65DBE6e6E570c4Bb6D";
    console.log("before replacing")
    console.log("source: ", await pureFiLinearPaymentPlan.vestingData(source))
    console.log("destination: ")
    try {
        await pureFiLinearPaymentPlan.vestingData(destination)
    }
    catch(e) {
        console.log("no tokens vested")
    }
    console.log("upgrading")

    await admin.upgrade(proxy, logic.address, { from: owner } );
    let pureFiLinearPaymentPlan2 = await PureFiLinearPaymentPlan2.at(proxy);
    await pureFiLinearPaymentPlan2.replaceVestingData( { from: owner } );
    await pureFiLinearPaymentPlan2.unpause( { from: owner } );

    console.log("after replacing")
    console.log("source: ")
    try {
        await pureFiLinearPaymentPlan.vestingData(source)
    }
    catch(e) {
        console.log("no tokens vested")
    }
    console.log("destination: ", await pureFiLinearPaymentPlan2.vestingData(destination))
  
    // invoke callback
    callback();
  }