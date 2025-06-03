// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Test,console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract OpenInvariantTest is StdInvariant, Test {
    DeployDsc deployer;
    DSCEngine public dscengine;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    function setUp() external {
        deployer = new DeployDsc();
        (dsc, dscengine, helperConfig) = deployer.run();
        targetContract(address(dscengine));

             (
            ethUsdPriceFeed,
            btcUsdPriceFeed,
            weth,
            wbtc,
            
        ) = helperConfig.activeNetworkConfig();
    
    }

          
      function invariant_protocolMustHaveMoreValueThanTotalSupply() public view{
        uint256 totalSupply=dsc.totalSupply();
        uint256 wethDeposited =IERC20(weth).balanceOf(address(dscengine));
        uint256 wbtcDeposited =IERC20(wbtc).balanceOf(address(dscengine));

        uint256 wethValue=dscengine._getUsdValue(weth, wethDeposited);
        uint256 wbtcValue=dscengine._getUsdValue(wbtc, wbtcDeposited);


       assert(wethValue+wbtcValue >= totalSupply);
      }   


}
