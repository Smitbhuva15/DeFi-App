// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract InvariantHandler is Test {
    DSCEngine public dscengine;
    DecentralizedStableCoin public dsc;

    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint96 public constant MAX_UINT = type(uint96).max;
    
    address [] public depositedCollateraladdresses;

    constructor(DSCEngine _dscengine, DecentralizedStableCoin _dsc) {
        dscengine = _dscengine;
        dsc = _dsc;
        address[] memory s_collateralTokens = _dscengine.getCollateralTokens();
        weth = ERC20Mock(s_collateralTokens[0]);
        wbtc = ERC20Mock(s_collateralTokens[1]);
    }

    function depositeCollateral(
        uint256 collateralindex,
        uint256 collateralAmount
    ) public {
        address colleteralAddress = getCollateraladdress(collateralindex);
        collateralAmount = bound(collateralAmount, 1, MAX_UINT);

        if (MAX_UINT == 0) {
            return; // if the max uint is 0, we can't use it as a bound
        }

        vm.startPrank(msg.sender);
        ERC20Mock(colleteralAddress).mint(msg.sender, collateralAmount); // manually give the user some tokens to deposit
        ERC20Mock(colleteralAddress).approve(
            address(dscengine),
            collateralAmount
        );
         depositedCollateraladdresses.push(colleteralAddress);
        dscengine.depositCollateral(colleteralAddress, collateralAmount);
        vm.stopPrank();
    }

    function redeemCollateral(
        uint256 collateralIndex,
        uint256 collateralAmount
    ) public {
         address collateral = getCollateraladdress(collateralIndex);
        uint256 maxCollateral = dscengine.getUserCollateralBalance(msg.sender, collateral);

        collateralAmount = bound(collateralAmount, 0, maxCollateral);
        // if the collateral amount is 0, we don't need to redeem anything
        if (collateralAmount == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        dscengine.redeemCollateral(address(collateral), collateralAmount);
    }


    function getCollateraladdress(
        uint256 collateralIndex
    ) public view returns (address) {
        if (collateralIndex % 2 == 0) {
            return address(weth);
        }

        return address(wbtc);
    }

    function mintDsc(uint256  amount,uint256 depositedCollateraladdressesindex) public{
        if(depositedCollateraladdressesindex==0){
            return;
        }
        address sender=depositedCollateraladdresses[depositedCollateraladdressesindex % depositedCollateraladdresses.length];
       vm.startPrank(sender);
      (uint256 totalDscMinted, uint256 collateralValueInUsd)= dscengine._getAccountInformation(sender);
      uint256 maxDscMintable =(collateralValueInUsd/2)-totalDscMinted;

      if(maxDscMintable < 0){
        return;
      }
      amount=bound(amount,0,uint256(maxDscMintable));

        if(amount == 0){
            return;
        }

        dscengine.mintDsc(amount);

       vm.stopPrank();
        
    }
}
