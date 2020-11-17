/*
Copyright (c) 2020, BitVerk
*/
pragma solidity ^0.4.26;

import "./sys_base.sol";

contract MarketFactory {
    function creatSpotPair(uint32 _id, address _tokenAdr, address _priceAdr) external returns (address);
}

contract MarketSpotPair {
    function setSpotHalted(bool _tag) external;
    function getSpotInfo() external view returns (uint8 tag, address[3] adrs);
    function getMarketPrices() external view returns (uint256 minSellingPrice, uint256 maxBuyingPrice);
    function numUserOrders(uint32 _userIdx) external view returns (uint32);
    function gerUserOrderByIdx(uint32 _userIdx, uint32 _idx) external view returns (uint8 status, uint40 orderId, uint32[2] times, uint128[3] values);
    function gerMarketOrderById(uint40 _orderId) external view returns (uint8 status, uint32[2] times, uint128[3] values);
    function cancelUserOrder(uint32 _userIdx, uint40 _orderId) external returns (bool sellingOrderTag, uint256 refund, uint256 tokenAmount, uint256 tokenPrice);
    function spotBuyToken(uint32 _takerIdx, uint256 _adjustedAmount, uint256 _adjustedPrice, uint32 _loops) external returns (uint256 totalRemain, uint256 totalBoughtNos, uint256 totalPayment);
    function spotSellToken(uint32 _takerIdx, uint256 _adjustedAmount, uint256 _adjustedPrice, uint256 _loops) external returns (uint256 totalRemain, uint256 totalSoldNos, uint256 totalProfit);
}

contract SysMarketSpotBase is SysBase {
    address[] dexes_;
    mapping(address => uint8) internal dexAvaiables_;
    mapping(address => uint32) internal dexIndice_;
    mapping(address => mapping(address => address)) internal dexByAdrs_;

    mapping(address => uint256) adrToDecimalsMap_;
    mapping(address => uint256) marketRevenues_;
    
    address[] internal users_;
    mapping(address => uint32) internal userIndice_;
    mapping(address => mapping(address => uint256)) userCryptos_;
    
    address internal revenueReceiver_;
    uint256 internal makerChargeRatioBy10k_;
    uint256 internal takerChargeRatioBy10k_;

    address internal marketFactory_;
    address internal posGm_;

    event ObtainRevenue(address indexed tokenAdr, address indexed user, uint256 amount);

    constructor(bytes32 _name) public SysBase(_name) {
    }
    
    function() external payable {
        revert();
    }

    function setSysGms() internal {
        users_.push(this);
        marketFactory_ = getModule("sysMarketFactory");
        posGm_ = getModule("sysPosGm");
    }

    ////////////////////////
    function getUserIdxByAdr(address _user) internal view returns (uint32) {
        return userIndice_[_user];
    }

    function registerUserIdxByAdr(address _user) internal returns (uint32) {
        uint32 userIdx = userIndice_[_user];
        if (userIdx == 0) {
            userIdx = uint32(users_.length);
            userIndice_[_user] = userIdx;
            users_.push(_user);
        }
        return userIdx;
    }

    function downScaleValue(uint256 _value, uint256 _decimals) internal pure returns (uint256 scaled) {
        if (_decimals == 18) {
            scaled = _value;
        } else if (_decimals < 18) {
            scaled = _value / (10 ** (18 - _decimals));
        } else {
            scaled = _value * (10 ** (_decimals - 18));
        }
    }

    function transferFromMarketToUser(address _tokenAdr, address _to, uint256 _amount) internal {
        uint256 preAmountOfTo = userCryptos_[_to][_tokenAdr];
        userCryptos_[_to][_tokenAdr] = preAmountOfTo.add(_amount);
    }

    function transferFromUserToMarket(address _tokenAdr, address _from, uint256 _amount, uint256 _ethValue) internal {
        uint256 decimals = adrToDecimalsMap_[_tokenAdr];
        uint256 preAmountOfFrom = userCryptos_[_from][_tokenAdr];

        if (preAmountOfFrom >= _amount) {
            userCryptos_[_from][_tokenAdr] = preAmountOfFrom - _amount;
            require(_ethValue == 0);
        } else {
            uint256 delta = _amount - preAmountOfFrom;
            if (_tokenAdr == address(0)) {
                require(_ethValue >= delta);
                userCryptos_[_from][_tokenAdr] = _ethValue - delta;
            } else {
                require(_ethValue == 0);
                ERC20Interface(_tokenAdr).transferFrom(_from, address(this), downScaleValue(delta, decimals));
                userCryptos_[_from][_tokenAdr] = 0;
            }
        }
    }

    function transferForWithdraw(address _tokenAdr, address _to, uint256 _amount) internal {
        if (_tokenAdr == address(0)) {
            bool ret = _to.call.value(_amount)("");
            require(ret);
        } else {
            uint256 decimals = adrToDecimalsMap_[_tokenAdr];
            uint256 amount = downScaleValue(_amount, decimals);
            ERC20Interface(_tokenAdr).transfer(_to, amount);
        }
    }    

    function setMarketRevenueInfo(address _receiver, uint32 _makerChargeRatio, uint32 _takerChargeRatio) external {
        checkDelegate(msg.sender, 1);
        require(_receiver != address(0));

        revenueReceiver_ = _receiver;
        makerChargeRatioBy10k_ = uint256(_makerChargeRatio);
        takerChargeRatioBy10k_ = uint256(_takerChargeRatio);
    }

    function getMarketRevenueInfo() external view returns (address, uint256, uint256) {
        return (revenueReceiver_, makerChargeRatioBy10k_, takerChargeRatioBy10k_);
    }

    ///////////////////////
    function getMarketRevenue(address _tokenAdr) external view returns (uint256) {
        return marketRevenues_[_tokenAdr];
    }

    function obtainMarketRevenue(address _tokenAdr, uint256 _tokenAmount) external {
        checkDelegate(msg.sender, 1);
        
        uint256 revenue = marketRevenues_[_tokenAdr];
        if (revenue >= _tokenAmount) {
            revenue = _tokenAmount;
        }
        marketRevenues_[_tokenAdr] -= revenue;

        transferForWithdraw(_tokenAdr, revenueReceiver_, revenue);
        emit ObtainRevenue(_tokenAdr, revenueReceiver_, revenue);
    }

    //////////////////
    function addSpot(address[2] _adrs) external {
        checkDelegate(msg.sender, 1);
        require(_adrs[0] != _adrs[1]);

        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        require(dexByAdrs_[_tokenAdr][_priceAdr] == address(0));

        if (_tokenAdr == address(0)) {
            adrToDecimalsMap_[_tokenAdr] = 18;
        } else {
            adrToDecimalsMap_[_tokenAdr] = ERC20Interface(_tokenAdr).decimals();
        }

        if (_priceAdr == address(0)) {
            adrToDecimalsMap_[_priceAdr] = 18;
        } else {
            adrToDecimalsMap_[_priceAdr] = ERC20Interface(_priceAdr).decimals();
        }

        uint32 index = uint32(dexes_.length);
        address dexAdr = MarketFactory(marketFactory_).creatSpotPair(index, _tokenAdr, _priceAdr);
        dexByAdrs_[_tokenAdr][_priceAdr] = dexAdr;
        dexAvaiables_[dexAdr] = 1;
        dexIndice_[dexAdr] = index;
        dexes_.push(address(dexAdr));
    }

    function pauseSpot(address[2] _adrs) external {
        checkDelegate(msg.sender, 1);
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        address dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];
        dexAvaiables_[dexAdr] = 0;

        MarketSpotPair(dexAdr).setSpotHalted(true);
    }

    function resumeSpot(address[2] _adrs) external {
        checkDelegate(msg.sender, 1);
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        address dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];
        dexAvaiables_[dexAdr] = 1;

        MarketSpotPair(dexAdr).setSpotHalted(false);
    }

    ///////////////////
    function numUsers() external view returns (uint32) {
        return uint32(users_.length);
    }

    function getUserIdByAdr(address _user) external view returns (uint32) {
        return userIndice_[_user];
    }

    function getUserAdrById(uint32 _idx) external view returns (address) {
        return users_[_idx];
    }
    
    function numSpots() external view returns (uint32) {
        return uint32(dexes_.length);
    }

    function getSpotId(address[2] _adrs) external view returns (uint32) {
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        address dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];
        return dexIndice_[dexAdr];
    }

    function getSpotAdr(address[2] _adrs) external view returns (address) {
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        return dexByAdrs_[_tokenAdr][_priceAdr];
    }

    function getSpotInfo(address[2] _adrs) external view returns (uint8 status, uint8 erc20Tag, uint32 idx, address dexAdr, address[3] memory adrs) {
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];
        require(dexAdr != address(0));

        status = dexAvaiables_[dexAdr];
        idx = dexIndice_[dexAdr];
        // mineable = mineableDexIndice_[idx];
        (erc20Tag, adrs) = MarketSpotPair(dexAdr).getSpotInfo();
    }

    function getSpotInfoByIdx(uint32 _idx) external view returns (uint8 status, uint8 erc20Tag, uint32 idx, address dexAdr, address[3] memory adrs) {
        require(_idx < uint32(dexes_.length));

        dexAdr = dexes_[_idx];
        status = dexAvaiables_[dexAdr];
        idx = _idx;
        (erc20Tag, adrs) = MarketSpotPair(dexAdr).getSpotInfo();
    }

    ///////////////////////////////
    function getUserTokenInfo(address _tokenAdr, address _user, address _spender) external view returns (uint32, uint256, uint256, uint256) {
        uint32 decimals;
        uint256 amount;
        uint256 approved;
        uint256 cryoto;

        if (_tokenAdr == address(0)) {
            decimals = 18;
            amount = address(_user).balance;
            approved = amount;
        } else {
            decimals = uint32(ERC20Interface(_tokenAdr).decimals());
            amount = ERC20Interface(_tokenAdr).balanceOf(_user);
            approved = ERC20Interface(_tokenAdr).allowance(_user, _spender);
        }
        cryoto = downScaleValue(userCryptos_[_user][_tokenAdr], adrToDecimalsMap_[_tokenAdr]);
        return (decimals, amount, approved, cryoto);
    }

    function getSpotMarketPrices(address[2] _adrs) external view returns (uint256 minSellingPrice, uint256 maxBuyingPrice) {
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        address dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];
        if (dexAdr == address(0)) {
            return (0, 0);
        } else {
            return MarketSpotPair(dexAdr).getMarketPrices();
        }
    }

    function numSpotUserOrders(address[2] _adrs, address _user) external view returns (uint32) {
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        address dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];
        uint32 userIdx = getUserIdxByAdr(_user);

        if (dexAdr == address(0) || userIdx == 0) {
            return 0;
        } else {
            return MarketSpotPair(dexAdr).numUserOrders(userIdx);
        }
    }

    function gerSpotUserOrderByIdx(address[2] _adrs, address _user, uint32 _idx) external view returns (uint8 status, uint40 orderId, uint32[2] memory times, uint128[3] memory values) {
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        address dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];
        uint32 userIdx = getUserIdxByAdr(_user);

        if (dexAdr == address(0) || userIdx == 0) {
            return (status, orderId, times, values);
        } else {
            return MarketSpotPair(dexAdr).gerUserOrderByIdx(userIdx, _idx);
        }
    }

    function gerSpotMarketOrderById(address[2] _adrs, uint40 _orderId) external view returns (uint8 status, uint32[2] memory times, uint128[3] memory values) {
        address _tokenAdr = _adrs[0];
        address _priceAdr = _adrs[1];

        address dexAdr = dexByAdrs_[_tokenAdr][_priceAdr];

        if (dexAdr == address(0)) {
            return (status, times, values);
        } else {
            return MarketSpotPair(dexAdr).gerMarketOrderById(_orderId);
        }
    }
}

contract SysMarketSpot is SysMarketSpotBase {
    uint48 optCount_ = 1;

    event SpotTaking(uint32 indexed spotPairId, uint32 indexed takerId, bool indexed isSell, uint88 amount, uint88 price, uint88 fee, uint32 time);
    event RecordOrder(uint48 indexed optCount, uint32 indexed spotPairId, uint32 indexed makerId, uint32 takerId, uint8 optTag, bool sellingOrder, bool increased, uint64 amount, uint64 price);
    event UserWithdraw(address indexed tokenAdr, address indexed user, uint256 amount, uint32 time);

    constructor(bytes32 _name) public SysMarketSpotBase(_name) {
    }

    ///////////////////////////////
    function updateUserWeightInfo(uint32 _dexId, uint32 _makerIdx, uint32 _takerIdx, uint8 _optTag, bool _sellingOrder, bool _increased, uint256 _amountEther, uint256 _priceEther) internal {
        uint256 amountSzabo = _amountEther / 10 ** 12;
        uint256 priceSzabo = _priceEther / 10 ** 12;

        emit RecordOrder(optCount_, _dexId, _makerIdx, _takerIdx, _optTag, _sellingOrder, _increased, uint64(amountSzabo), uint64(priceSzabo));
        optCount_++;
    }

    ///////////////////////////////
    function checkAmountViaSelling(uint256[2] _values) internal pure returns (uint256 adjustedAmount, uint256 adjustedPrice) {
        adjustedAmount = _values[0] / 10**14;
        adjustedPrice =  _values[1] / 10**12;

        require(adjustedAmount <= 1000000);

        adjustedAmount *= 10**14;
        adjustedPrice *= 10**12;
        require(adjustedAmount > 0);
        require(adjustedPrice > 0);
    }

    function checkAmountViaBuying(uint256[2] _values) internal pure returns (uint256 adjustedAmount, uint256 adjustedPrice, uint256 inputBalance) {
        adjustedAmount = _values[0] / 10**14;
        adjustedPrice =  _values[1] / 10**12;

        require(adjustedAmount <= 1000000);

        adjustedAmount *= 10**14;
        adjustedPrice *= 10**12;

        inputBalance = (adjustedAmount.mul(adjustedPrice)) / (1 ether);
        require(inputBalance > 0);
    }
    
    ///////////////////////////////
    /**
    * @dev callback from the MarketSpotPair object
    */
    function cb_dealwithTokenToMaker(uint32 _orderOwnerIdx, uint32 _takerIdx, address _tokenAdr, uint256 _amount, bool _sellingOrder, uint256 _askNos, uint256 _askPrice) external {
        require(dexAvaiables_[msg.sender] ==1);
        uint32 adxId = dexIndice_[msg.sender];
        address user = users_[_orderOwnerIdx];
        uint256 revenue = 0;

        if (makerChargeRatioBy10k_ > 0) {
            revenue = (_amount.mul(makerChargeRatioBy10k_)) / 10000;
            marketRevenues_[_tokenAdr] = marketRevenues_[_tokenAdr].add(revenue);
        } 
        transferFromMarketToUser(_tokenAdr, user, _amount - revenue);

        updateUserWeightInfo(adxId, _orderOwnerIdx, _takerIdx, 2, _sellingOrder, false, _askNos, _askPrice);
    }

    ////////////////////////
    /**
    * @dev withdraw tokens by a user
    */
    function withdrawToken(address _tokenAdr) external {
        address user = msg.sender;
        uint32 userIdx = getUserIdxByAdr(user);
        require(userIdx > 0);

        uint256 amount = userCryptos_[user][_tokenAdr];
        require(amount > 0);

        userCryptos_[user][_tokenAdr] = 0;

        transferForWithdraw(_tokenAdr, user, amount);
        emit UserWithdraw(_tokenAdr, user, amount, uint32(now));
    }
    
    /**
    * @dev cancel a placed order even if the portion of amount swapped already
    * @param _adrs [0] The address of token to be sold.
    * @param _adrs [1] The address of token related to payment.
    * @param _userOrderId The order id.
    */
    function cancelOrder(address[2] _adrs, uint40 _userOrderId) external {
        address dexAdr = dexByAdrs_[_adrs[0]][_adrs[1]];
        require(dexAvaiables_[dexAdr] == 1);

        uint32 userIdx = getUserIdxByAdr(msg.sender);
        require(userIdx > 0);

        bool sellingOrderTag;
        uint256 tokenPrice;
        uint256 tokenAmount;
        uint256 refundAmount;

        (sellingOrderTag, refundAmount, tokenAmount, tokenPrice) = MarketSpotPair(dexAdr).cancelUserOrder(userIdx, uint40(_userOrderId));
        if (sellingOrderTag) {
            transferFromMarketToUser(_adrs[0], msg.sender, refundAmount);
        } else {
            transferFromMarketToUser(_adrs[1], msg.sender, refundAmount);
        }

        updateUserWeightInfo(dexIndice_[dexAdr], userIdx, 0, 3, sellingOrderTag, false, tokenAmount, tokenPrice);
    }

    /**
    * @dev place a limit sell order
    * @param _adrs [0] The address of token to be bought.
    * @param _adrs [1] The address of token related to payment.
    * @param _values [0] The expected amount of token to be bought.
    * @param _values [1] The token price.
    * @param _loops The maximum of doing order matching.
    */
    function placeSellOrder(address[2] _adrs, uint256[2] _values, uint32 _loops) external payable {
        require(!halted_);
        address dexAdr = dexByAdrs_[_adrs[0]][_adrs[1]];
        require(dexAvaiables_[dexAdr] == 1);

        uint32 userIdx = registerUserIdxByAdr(msg.sender);
        uint256 adjustedAmount;
        uint256 adjustedPrice;
        (adjustedAmount, adjustedPrice) = checkAmountViaSelling(_values);

        uint256 soldNos;
        uint256 profit;
        uint256 remainAmount;

        transferFromUserToMarket(_adrs[0], msg.sender, adjustedAmount, msg.value);

        (remainAmount, soldNos, profit) = MarketSpotPair(dexAdr).spotSellToken(userIdx, adjustedAmount, adjustedPrice, _loops);

        if (profit > 0) {
            uint256 chargedFee = chargedFee = (profit.mul(takerChargeRatioBy10k_)) / 10000;
            marketRevenues_[_adrs[1]] = marketRevenues_[_adrs[1]].add(chargedFee);
            // spotFees_[dexAdr].priceFee_ += uint128(chargedFee);

            // transfer profit to user
            transferFromMarketToUser(_adrs[1], msg.sender, profit.sub(chargedFee));

            emit SpotTaking(dexIndice_[dexAdr], userIdx, true, uint88(soldNos), uint80(profit * (1 ether) / soldNos), uint88(chargedFee), uint32(now));
        }

        if (remainAmount > 0) {
            // refund the rest of tokens
            transferFromMarketToUser(_adrs[0], msg.sender, adjustedAmount.sub(soldNos));
        } else {
            // the remain selling are placed
            uint256 delta = adjustedAmount.sub(soldNos);
            if (delta > 0) {
                updateUserWeightInfo(dexIndice_[dexAdr], userIdx, 0, 1, true, true, delta, adjustedPrice);
            }
        }
    }

    /**
    * @dev place a limit order
    * @param _adrs [0] The address of token to be sold.
    * @param _adrs [1] The address of token related to payment.
    * @param _values [0] The expected amount of token to be sold.
    * @param _values [1] The token price.
    * @param _loops The maximum of doing order matching.
    */
    function placeBuyOrder(address[2] _adrs, uint256[2] _values, uint32 _loops) external payable {
        require(!halted_);
        address dexAdr = dexByAdrs_[_adrs[0]][_adrs[1]];
        require(dexAvaiables_[dexAdr] == 1);

        uint32 userIdx = registerUserIdxByAdr(msg.sender);
        uint256 adjustedAmount;
        uint256 adjustedPrice;
        uint256 inputBalance;
        (adjustedAmount, adjustedPrice, inputBalance) = checkAmountViaBuying(_values);

        uint256 remainAmount;
        uint256 boughNos;
        uint256 payment; 

        transferFromUserToMarket(_adrs[1], msg.sender, inputBalance, msg.value);

        (remainAmount, boughNos, payment) = MarketSpotPair(dexAdr).spotBuyToken(userIdx, adjustedAmount, adjustedPrice, _loops);

        if (boughNos > 0) {
            uint256 chargedFee = (boughNos.mul(takerChargeRatioBy10k_)) / 10000;
            marketRevenues_[_adrs[0]] = marketRevenues_[_adrs[0]].add(chargedFee);

            // transfer tokens to user
            transferFromMarketToUser(_adrs[0], msg.sender, boughNos.sub(chargedFee));

            emit SpotTaking(dexIndice_[dexAdr], userIdx, false, uint88(boughNos), uint80(payment * (1 ether) / boughNos), uint88(chargedFee), uint32(now));
        }    

        if (remainAmount > 0) {
            // refund the rest of pre-payment
            transferFromMarketToUser(_adrs[1], msg.sender, inputBalance.sub(payment));
        } else {
            // the remain buying are placed
            uint256 delta = adjustedAmount.sub(boughNos);
            if (delta > 0) {
                updateUserWeightInfo(dexIndice_[dexAdr], userIdx, 0, 1, false, true, delta, adjustedPrice);
            }
        }
    }
}
