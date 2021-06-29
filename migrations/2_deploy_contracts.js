const PureFiToken = artifacts.require('PureFiToken');

module.exports = async function (deployer, network, accounts) {
    
    let admin = accounts[0];
    let trustedForwarder;

    if(network == 'rinkeby' || network == 'rinkeby-fork'){
        trustedForwarder = '0x83A54884bE4657706785D7309cf46B58FE5f6e8a';
    } else if(network == 'mainnet' || network == 'mainnet-fork'){
        trustedForwarder = '0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA';
    } else if(network == 'kovan' || network == 'kovan-fork'){
        trustedForwarder = '0x7eEae829DF28F9Ce522274D5771A6Be91d00E5ED';
    }else if(network == 'ropsten' || network == 'ropsten-fork'){
        trustedForwarder = '0xeB230bF62267E94e657b5cbE74bdcea78EB3a5AB';
    }else if(network == 'test'){
        trustedForwarder = '0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA';
    }

    console.log("Deploy: Admin: "+admin);
    console.log("Deploy: forwarder: "+trustedForwarder);

    
    let pureFiToken;
    await deployer.deploy(PureFiToken, admin, trustedForwarder)
    .then(function(){
        console.log("PureFiToken.address: ", PureFiToken.address);
        return PureFiToken.at(PureFiToken.address);
    }).then(function (instance){
        pureFiToken = instance; 
    });

};