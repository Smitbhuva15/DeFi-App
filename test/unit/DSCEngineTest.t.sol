// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Test,console} from 'forge-std/Test.sol';
import { DeployDsc } from "../../script/DeployDsc.s.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";



contract DSCEngineTest is Test{

    DSCEngine public dscengine;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    address public USER=makeAddr("user");

     uint256 amountCollateral = 10 ether;


    function setUp() external {
         DeployDsc deployer = new DeployDsc();

         
         (dsc, dscengine, helperConfig) = deployer.run();

        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, 100 ether);
        


    }
    
    ////////////////////////////////////////////////    Price Tests    ///////////////////////////////////////////////////

     function testGetUsdValue() public view {
        // 15e18 ETH * $2000/ETH = $30,000e18

        uint256 ethAmount = 15e18;

        uint256 expectedUsd = 30000e18;
        
        uint256 usdValue = dscengine._getUsdValue(weth, ethAmount);

        assertEq(usdValue, expectedUsd);
        
    }


    ////////////////////////////////////////////////    DepositeCollateral Tests    //////////////////////////////////////////////////

    function testRevertIfCollateralZero() public{
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dscengine), amountCollateral);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscengine.depositCollateral(weth,0);
        
        
        vm.stopPrank();
        
    }


        


}