// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {OptimismParameters} from "./utils/parameters/OptimismParameters.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {Conversion} from "src/Conversion.sol";

/// @title Kwenta deployment script
/// @author JaredBorders (jaredborders@pm.me)
contract Setup is Script {
    function deploySystem(address _kwenta, address _snx)
        public
        returns (address)
    {
        Conversion conversion = new Conversion(_kwenta, _snx);
        return address(conversion);
    }
}

/// @dev steps to deploy and verify on Optimism:
/// (1) load the variables in the .env file via `source .env`
/// (2) run `forge script script/Deploy.s.sol:DeployOptimism --rpc-url $OPTIMISM_RPC_URL --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY --broadcast --verify -vvvv`
contract DeployOptimism is Setup, OptimismParameters {
    function run() public returns (address) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        address conversion = Setup.deploySystem(OPTIMISM_KWENTA, OPTIMISM_SNX);

        vm.stopBroadcast();
        return address(conversion);
    }
}
