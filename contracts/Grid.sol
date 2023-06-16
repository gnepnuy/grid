// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./IDecimalERC20.sol";
import "hardhat/console.sol";




contract Grid is Context, ReentrancyGuard{

    address public immutable swap_router;
    address public immutable factory;
    address public immutable weth;
    address public immutable stable;//稳定币，usds
    uint24 public immutable fee;//制定池子手续费
    uint256 public immutable interval_price_min;//最小价格区间
    uint256 public immutable grid_amount_min;//最小的网格数量

    uint256 public immutable base_bounty_eth;//基础gas费，eth计价
    uint256 public immutable base_bounty_stable;//基础gas费，usds计价
    uint16 public immutable slippage;

    Order[] public orders;//网格订单数组
    Position[] public positions;//仓位
    mapping (uint256 => address) public orderToOwner;//订单所有者
    mapping (uint256 => uint256[]) public orderToPosition;//订单仓位数组

    enum Side {Buy,Sell,Bilateral}
    enum PositionStatus {InPosition,Over}
    enum OrderStatus {Open,Close}

    struct Position {
        Side side;
        PositionStatus status;
        uint256 order_id;
        uint256 selling_price;
        uint256 cost_price;
        uint256 amount;
        address creator;
    }

    struct  Order {
        Side side;
        OrderStatus status;
        uint256 min_price;
        uint256 max_price;
        uint256 init_amount;
        uint256 init_price;// that sell coin the price
        uint256 last_price;
        uint256 interval_price;
        uint256 share_amount;//每次买入/卖出的份额大小
        uint256 balance;
    }


    event CreateOrder(address indexed owner,uint256 order_id,uint256 amount,Side side);
    event StopOrder(uint256 indexed order_id,address owner);
    event CloseOrder(uint256 indexed order_id,address owner);
    event CreatePosition(uint256 indexed order_id,address indexed creator,uint256 position_id,uint256 amount,Side side);
    event ClosePosition(uint256 indexed position_id,uint256 indexed order_id,address operator,uint256 income,Side side);

    constructor(
        address _factory,
        address _swap_router,
        address _weth,
        address _stable,
        uint24 _fee,
        uint256 _interval_price_min,
        uint256 _grid_amount_min,
        uint256 _base_bounty_eth,
        uint256 _base_bounty_stable,
        uint16 _slippage){
        factory = _factory;
        swap_router = _swap_router;
        weth = _weth;
        stable = _stable;
        fee = _fee;
        interval_price_min = _interval_price_min;
        grid_amount_min = _grid_amount_min;
        base_bounty_eth = _base_bounty_eth;
        base_bounty_stable = _base_bounty_stable;
        slippage = _slippage;
    }

    function createGrid(
        Side side,
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _interval_price,
        uint256 _share_amount) external nonReentrant() {

        require(_interval_price >= interval_price_min,'price interval is too small');

        uint256 current_price = _getEthPrice();

        require(current_price  <= _max_price 
                && current_price  >= _min_price,'price range is too small');
        require(_share_amount <= _init_amount/grid_amount_min ,'too few grids');

        require(_init_amount > 0,'need to put money in');
        // todo: set investment threshold

        IERC20(stable).transferFrom(_msgSender(),address(this),_init_amount);
        
        if(side == Side.Buy){
            _createBuyGrid(_min_price,_max_price,_init_amount,current_price,_interval_price,_share_amount);
        }else if (side == Side.Sell){
            _createSellGrid(_min_price,_max_price,_init_amount,_interval_price,_share_amount);
        }else{
            _createBuyAndSellGrid(_min_price,_max_price,_init_amount,current_price,_interval_price,_share_amount);
        }
    }

    function _createBuyAndSellGrid(
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _init_price,
        uint256 _interval_price,
        uint256 _share_amount)internal{

        _createBuyGrid(_min_price,_max_price,_init_amount/2,_init_price,_interval_price,_share_amount);
        _createSellGrid(_min_price,_max_price,_init_amount/2,_interval_price,_share_amount);
    }

    function _createSellGrid(
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _interval_price,
        uint256 _share_amount)internal{

        uint256 receive_amount = _buy(_init_amount);
        uint256 price = _getEthPrice();

        uint256 share_amount = (_share_amount * (10 ** IDecimalERC20(weth).decimals())) / price;
   
        orders.push(Order(
            Side.Sell,
            OrderStatus.Open,
            _min_price,
            _max_price,
            receive_amount,
            price,
            price,
            _interval_price,
            share_amount,
            receive_amount
        ));
        orderToOwner[orders.length - 1] = _msgSender();
        emit CreateOrder(_msgSender(),orders.length - 1,_init_amount,Side.Sell);
    }

    function _createBuyGrid(
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _init_price,
        uint256 _interval_price,
        uint256 _share_amount)internal{
        orders.push(Order(
            Side.Buy,
            OrderStatus.Open,
            _min_price,
            _max_price,
            _init_amount,
            _init_price,
            _init_price,
            _interval_price,
            _share_amount,
            _init_amount
        ));
        orderToOwner[orders.length - 1] = _msgSender();
        emit CreateOrder(_msgSender(),orders.length - 1,_init_amount,Side.Buy);
    }

    function closeOrder(uint256 _order_id)external nonReentrant {
        Order storage order = orders[_order_id];
        require(order.min_price > 0,"order dose not exist");
        require(orderToOwner[_order_id] == _msgSender(),"not your order");
        require(order.status != OrderStatus.Close,"order is closed");
       
        if(order.balance > 0){
            if(order.side == Side.Buy){
                IERC20(stable).transfer(_msgSender(),order.balance);
            }else{
                IERC20(weth).transfer(_msgSender(),order.balance);
            }
            order.balance = 0;
        }
        order.status = OrderStatus.Close;
        emit CloseOrder(_order_id,_msgSender());
        _forceClosePosition(orderToPosition[_order_id]);   
    }

    function _forceClosePosition(uint256[] memory _position_ids)internal {
        uint256 eth_amount;
        uint256 stable_amount;
        for(uint256 i = 0; i < _position_ids.length; ++i){
            Position storage position = positions[_position_ids[i]];
            if(position.status == PositionStatus.InPosition){
                if(position.side == Side.Buy){
                    eth_amount += position.amount - base_bounty_eth;
                    IERC20(weth).transfer(position.creator,base_bounty_eth);
                }else{
                    stable_amount += position.amount - base_bounty_stable;
                    IERC20(stable).transfer(position.creator,base_bounty_stable);
                }
                position.status = PositionStatus.Over;
                emit ClosePosition(_position_ids[i],position.order_id,_msgSender(),0,position.side);
            }
        }
        if(eth_amount > 0){
            IERC20(weth).transfer(_msgSender(),eth_amount);
        }
        if(stable_amount > 0){
            IERC20(stable).transfer(_msgSender(),stable_amount);
        }
    }

    function buy(uint256 _order_id)external nonReentrant{
        Order storage order = orders[_order_id];
        require(order.min_price > 0,"order dose not exist");
        require(order.status == OrderStatus.Open,"order not opened");
        uint256 current_price = _getEthPrice();
        require(current_price >= order.min_price && current_price <= order.max_price,"the price exceeds the order range");
        require(order.side == Side.Buy,"order dose not exist");
        require(order.last_price - order.interval_price > current_price,"the price is not within the buying range");

        require(order.balance >= order.share_amount,"insufficient balance");
        order.balance -= order.share_amount;
        uint256 eth_amount = _buy(order.share_amount);
        uint256 tx_price = _getPriceByTx(order.share_amount,eth_amount,
                                            IDecimalERC20(stable).decimals(),IDecimalERC20(weth).decimals());
        require(order.last_price - order.interval_price > tx_price,"the price is not within the buying range");
        order.last_price = tx_price;
        
        positions.push(Position(
            Side.Buy,
            PositionStatus.InPosition,
            _order_id,
            0,
            tx_price,
            eth_amount,
            _msgSender()
        ));
        orderToPosition[_order_id].push(positions.length - 1);
        emit CreatePosition(_order_id,_msgSender(),positions.length - 1,eth_amount,Side.Buy);        
    }

    function sell(uint256 _order_id)external nonReentrant{
        Order storage order = orders[_order_id];
        require(order.min_price > 0,"order dose not exist");
        require(order.status == OrderStatus.Open,"order not opened");
        uint256 current_price = _getEthPrice();
        require(current_price >= order.min_price && current_price <= order.max_price,"the price exceeds the order range");
        require(order.side == Side.Sell,"order dose not exist");
        require(order.last_price + order.interval_price < current_price,"the price is not within the selling range");
        require(order.balance >= order.share_amount,"insufficient balance");

        order.balance -= order.share_amount;
        uint256 stable_amount = _sell(order.share_amount);
        uint256 tx_price = _getPriceByTx(stable_amount,order.share_amount,
                                            IDecimalERC20(stable).decimals(),IDecimalERC20(weth).decimals());
        require(order.last_price + order.interval_price < tx_price,"the price is not within the selling range");
        order.last_price = tx_price;

        positions.push(Position(
            Side.Sell,
            PositionStatus.InPosition,
            _order_id,
            0,
            tx_price,
            stable_amount,
            _msgSender()
        ));
        orderToPosition[_order_id].push(positions.length - 1);
        emit CreatePosition(_order_id,_msgSender(),positions.length - 1,stable_amount,Side.Sell);        
    }

    function closePosition(uint256 _position_id)external nonReentrant{
        Position storage position = positions[_position_id];
        require(position.amount > 0,"position dose not exist");
        require(position.status == PositionStatus.InPosition,"position has been close");
        uint256 current_price = _getEthPrice();
        Order storage order = orders[position.order_id];
        uint256 income;
        if(position.side == Side.Sell){
            require(current_price < position.cost_price - order.interval_price,
                                    "The current price is no longer in the closing range");
            uint256 eth_amount = _buy(position.amount);
            require(eth_amount > order.share_amount,"losing trade");
            income = eth_amount - order.share_amount;
            uint256 bounty = income * 200/1000;
            if(_msgSender() != position.creator){
                IERC20(weth).transfer(_msgSender(),bounty/2);
                IERC20(weth).transfer(position.creator,bounty/2);
            }else {
                IERC20(weth).transfer(_msgSender(),bounty);
            }
            
            order.last_price = _getPriceByTx(position.amount,eth_amount,
                                    IDecimalERC20(stable).decimals(),IDecimalERC20(weth).decimals());
            if(order.status == OrderStatus.Close){
                IERC20(weth).transfer(orderToOwner[position.order_id],eth_amount - bounty);
            }else {
                order.balance += eth_amount - bounty;
            }
        }else{
            require(current_price > position.cost_price + order.interval_price,
                                    "The current price is no longer in the closing range");
            uint256 stable_amount = _sell(position.amount);
            require(stable_amount > order.share_amount,"losing trade");
            income = stable_amount - order.share_amount;
            uint256 bounty = income * 200/1000;
            if(_msgSender() != position.creator){
                IERC20(stable).transfer(_msgSender(),bounty/2);
                IERC20(stable).transfer(position.creator,bounty/2);
            }else{
                IERC20(stable).transfer(_msgSender(),bounty);
            }
            
            order.last_price = _getPriceByTx(stable_amount,position.amount,
                                    IDecimalERC20(stable).decimals(),IDecimalERC20(weth).decimals());
            if(order.status == OrderStatus.Close){
                IERC20(stable).transfer(orderToOwner[position.order_id],stable_amount - bounty);
            }else {
                order.balance += stable_amount - bounty;
            }
        }

        position.status = PositionStatus.Over;
        position.selling_price = order.last_price;
        emit ClosePosition(_position_id,position.order_id,_msgSender(),income,position.side);
    }

    function getPrice() external view returns (uint256 price){
        price = _getEthPrice();
    }

    function _getPriceByTx(uint256 _base_amount,uint256 _quote_amount,uint8 _base_decimals,uint8 _quote_decimals) 
        internal pure returns(uint256 price){
        //if no decimals => _base_amount/_quote_amount
        price = _base_amount * 10 ** _base_decimals / (_quote_amount * 10 ** _base_decimals / 10 ** _quote_decimals);
    }

    function _getEthPrice()internal view returns (uint256 price){
        (, int24 tick,,,,,) = IUniswapV3Pool(_getPool(weth,stable,fee)).slot0();
        uint128 ethAmount = 1 ether;
        price = OracleLibrary.getQuoteAtTick(tick,ethAmount,weth,stable);
    }

    function _getAmountOut(address _token_in,address _token_out,uint256 _amount_in,uint24 _fee) internal view returns (uint256 amountOut){
        (, int24 tick,,,,,) = IUniswapV3Pool(_getPool(_token_in,_token_out,_fee)).slot0();
        amountOut = OracleLibrary.getQuoteAtTick(tick,uint128(_amount_in),_token_in,_token_out);
    }

    function _buy(uint256 amount)internal returns (uint256 receive_amount){
        uint256 eth_balance_before = IERC20(weth).balanceOf(address(this));
        _swap(stable,weth,amount);
        uint256 eth_balance_after = IERC20(weth).balanceOf(address(this));
        receive_amount = eth_balance_after - eth_balance_before;
    }

    function _sell(uint256 amount)internal returns(uint256 receive_amount){
        uint256 stable_balance_before = IERC20(stable).balanceOf(address(this));
        _swap(weth,stable,amount);
        uint256 stable_balance_after = IERC20(stable).balanceOf(address(this));
        receive_amount = stable_balance_after - stable_balance_before;
    }

    function  _swap(address token_in,address token_out,uint256 amount_in)internal{
        uint256 quotation = _getAmountOut(token_in,token_out,amount_in,fee);
        quotation = quotation - (quotation * slippage / 10000);
        ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: token_in,
                tokenOut: token_out,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount_in,
                amountOutMinimum: quotation,
                sqrtPriceLimitX96: 0
            });
        IERC20(token_in).approve(swap_router,amount_in);
        ISwapRouter(swap_router).exactInputSingle(params);

    }

    function _getPool(address tokenA,address tokenB,uint24 _fee) internal view returns(address pool){
        pool = PoolAddress.computeAddress(factory,PoolAddress.getPoolKey(tokenA,tokenB,_fee));
    }   

}