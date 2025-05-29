// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine {



    //////////////////////////////////////         errors       ///////////////////////////////////////////////

    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();



    DecentralizedStableCoin private immutable i_dsc;



    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; //  meThisans you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    ///////////////////////////////////////////  Mapping   ///////////////////////////////////////////

    mapping(address user => mapping(address collateralToken => uint256 amount))
        private s_collateralDeposited;

    mapping(address collateralToken => address priceFeed) private s_priceFeeds;

    mapping(address user => uint256 amount) private s_DSCMinted;

    address[] private s_collateralTokens;

    //////////////////////////////////////////////   events   ///////////////////////////////////////////

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    event CollateralRedeem(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    //////////////////////////////////////////////  modifier   ///////////////////////////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {

        
        if (s_priceFeeds[token] == address(0)) {
            
            revert DSCEngine__TokenNotAllowed(token);

        }
        _;
    }

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        // These feeds will be the USD pairs
        // For example ETH / USD or MKR / USD

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        //// for set the owner
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////////////////          external       ///////////////////////////////////////////

     function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) {
        s_DSCMinted[msg.sender] += amountDscToMint;

        revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        if (minted != true) {
            revert DSCEngine__MintFailed();
        }
    }

    function depositCollateralAndMintDsc( address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint) external{
           depositCollateral(tokenCollateralAddress,amountCollateral);
           
           mintDsc(amountDscToMint);
    }

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc(address redeemCollateralAddress,uint256 amountToRedeemCollatral,uint256 amountDscToBurn) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(redeemCollateralAddress, amountToRedeemCollatral);
    }

    
  //  after Redeem HealthFactor must be grether than zero
    function redeemCollateral(address redeemCollateralAddress,uint256 amountToRedeemCollatral) public moreThanZero(amountToRedeemCollatral){

        s_collateralDeposited[msg.sender][redeemCollateralAddress]-=amountToRedeemCollatral;
        emit CollateralRedeem(msg.sender,redeemCollateralAddress,amountToRedeemCollatral);

        (bool success)=IERC20(redeemCollateralAddress).transfer(msg.sender, amountToRedeemCollatral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }

        revertIfHealthFactorIsBroken(msg.sender);

    }

   

    function burnDsc(uint256 amountDscToBurn) public moreThanZero(amountDscToBurn){
          i_dsc.burn(amountDscToBurn);
          revertIfHealthFactorIsBroken(msg.sender);  // never possible
    }

    function liquidate() external {}

    function getMinHealthFactor() external {}

    ///////////////////////////////////////////    internal    ///////////////////////////////////////////

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ///////////////////////////////////////// Private & Internal View & Pure Functions  ///////////////////////////////////////////

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

            
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    ///////////////////////////////////////////  public view  function  ///////////////////////////////////////////

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }
}
