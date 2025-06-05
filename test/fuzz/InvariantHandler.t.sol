// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;
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


    constructor(DSCEngine _dscengine, DecentralizedStableCoin _dsc) {
        dscengine = _dscengine;
        dsc = _dsc;
        address [] memory s_collateralTokens= _dscengine.getCollateralTokens();
        weth = ERC20Mock(s_collateralTokens[0]);
        wbtc = ERC20Mock(s_collateralTokens[1]);
    }

    function depositeCollateral(
        uint256 collateralindex,
        uint256  collateralAmount) public{
         address colleteralAddress = getCollateraladdress(collateralindex);
         collateralAmount=bound(collateralAmount, 1, MAX_UINT);


         vm.startPrank(msg.sender);
         ERC20Mock(colleteralAddress).mint(
            msg.sender,
            collateralAmount);      // manually give the user some tokens to deposit
         ERC20Mock(colleteralAddress).approve(
            address(dscengine),
            collateralAmount);

         dscengine.depositCollateral(colleteralAddress, collateralAmount);
         vm.stopPrank();
            
        }
        
 
     function getCollateraladdress(uint256 collateralIndex) public view returns (address) {
         if(collateralIndex %2 == 0) {
             return address(weth);
         } 

         return address(wbtc);

     }

}
