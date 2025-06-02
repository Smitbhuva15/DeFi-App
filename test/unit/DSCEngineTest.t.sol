// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DSCEngine public dscengine;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    address public USER = makeAddr("user");

    uint256 amountCollateral = 10 ether;
    uint256 amountMinted = 5 ether;
    uint256 amountBurn = 15 ether;

    function setUp() external {
        DeployDsc deployer = new DeployDsc();

        (dsc, dscengine, helperConfig) = deployer.run();

        (
            ethUsdPriceFeed,
            btcUsdPriceFeed,
            weth,
            wbtc,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, 100 ether);
    }

    ////////////////////////////////////////////////   constructor Tests    ///////////////////////////////////////////////////

    address[] public token;
    address[] public priceFeed;

    function testIfPriceFeedandTokenLenghtNotSameRevert() public {
        token.push(weth);
        priceFeed.push(ethUsdPriceFeed);
        priceFeed.push(btcUsdPriceFeed);
        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch
                .selector
        );

        new DSCEngine(token, priceFeed, address(dsc));
    }

    ////////////////////////////////////////////////    Price Tests    ///////////////////////////////////////////////////

    function testGetUsdValue() public view {
        // 15e18 ETH * $2000/ETH = $30,000e18

        uint256 ethAmount = 15e18;

        uint256 expectedUsd = 30000e18;

        uint256 usdValue = dscengine._getUsdValue(weth, ethAmount);

        assertEq(usdValue, expectedUsd);
    }

    function testgetTokenAmountFromUsd() public view {
        uint256 usdAmountInWei = 1000e18; //pass 1000 usd --->dsc coin   /// 1 usd  == 1e18 represent usd
        uint256 expectedAnswer = 0.5 ether;

        uint256 realAnswer = dscengine.getTokenAmountFromUsd(
            weth,
            usdAmountInWei
        );
        assertEq(realAnswer, expectedAnswer);
    }

    ////////////////////////////////////////////////    DepositeCollateral Tests    //////////////////////////////////////////////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dscengine), amountCollateral);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscengine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock(
            "RAN",
            "RAN",
            USER,
            amountCollateral
        );
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__TokenNotAllowed.selector,
                address(randToken)
            )
        );
        dscengine.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositeCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscengine), amountCollateral);
        dscengine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testDepositCollateralandGetAccountInfo()
        public
        depositeCollateral
    {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscengine
            .getAccountInfo(USER);
        uint256 expectedDepositedAmout = dscengine.getTokenAmountFromUsd(
            weth,
            collateralValueInUsd
        );

        assertEq(0, totalDscMinted);
        assertEq(amountCollateral, expectedDepositedAmout);
    }

    // function testHelthFactor() public depositeCollateral {
    //     // (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscengine.getAccountInfo(USER);
    //     uint256 healthFactor = dscengine._healthFactor(USER);
    //     uint256 expectedHealthFactor = 1;
    //     console.log(healthFactor);

    //     assertEq(healthFactor, expectedHealthFactor);
    // }

    function testCanMintDscSuccessfully() public depositeCollateral {
        vm.startPrank(USER);
        dscengine.mintDsc(amountMinted);
        assertEq(dsc.balanceOf(USER), amountMinted);
        vm.stopPrank();
    }

    function testRevertsIfHealthFactorIsBroken() public {
        vm.startPrank(USER);
        vm.expectRevert();
        dscengine.mintDsc(amountMinted);
        vm.stopPrank();
    }

    function testBurnRevertsIfBurningMoreThanBalance()
        public
        depositeCollateral
    {
        vm.startPrank(USER);
        dscengine.mintDsc(amountMinted);

        vm.expectRevert();
        dscengine.burnDsc(amountBurn);

        vm.stopPrank();
    }

    function testBurnSuccessfully() public depositeCollateral {
        vm.startPrank(USER);
        dscengine.mintDsc(amountMinted);

        dsc.approve(address(dscengine), amountMinted);

        dscengine.burnDsc(amountMinted);

        assertEq(0, dsc.balanceOf(USER));

        vm.stopPrank();
    }

    function testredeemCollateralSuccessFully() public depositeCollateral {
        vm.startPrank(USER);
        dscengine.redeemCollateral(weth,amountMinted);
        vm.stopPrank();
    }

}
