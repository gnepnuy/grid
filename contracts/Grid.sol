// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Operator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//这里本想写网格交易的方法，写着写着又衍生出抄底的策略
//索性先不想那么多，直接根据币安的现货网格来吧，存入的起始资金固定为usdc，
//创建网格的时候拿一半的usdc换成eth,这样就能得到一个起始价，这个价格就变成一个游标了
//再来说说抄底策略，可以限定从什么价格开始，或者时间，这里又可以延伸出卖出策略
// 写到后边发现之前设想的方式存在问题，如果用一个订单来记录买与卖两部分数据不大好，
//不大好体现在更复杂，数据显得比较乱，所以决定把买与卖的数据分开为两个订单来存储，
//这样也直接实现了，抄底策略跟卖出策略

contract Grid is Operator,ReentrancyGuard{


    address public immutable stable;
    uint256 public immutable interval_price_min;
    uint256 public immutable grid_amount_min;

    uint256 public base_bounty_eth;
    uint256 public base_bounty_stable;

    Order[] public orders;
    Transaction[] public transactions;
    mapping (uint256 => address) public orderToOwner;
    mapping (uint256 => uint256[]) public orderToTransaction;

    enum Side {Buy,Sell,Bilateral}
    enum TxStatus {InPosition,Over}
    enum OrderStatus {Open,Stop,Close}

    struct Transaction {
        Side side;
        TxStatus status;
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
        uint256 share_amount;
        uint256 balance;
    }

    constructor(
        address _stable,
        uint256 _interval_price_min,
        uint256 _grid_amount_min,
        uint256 _base_bounty_eth,
        uint256 _base_bounty_stable){
        stable = _stable;
        interval_price_min = _interval_price_min;
        grid_amount_min = _grid_amount_min;
        base_bounty_eth = _base_bounty_eth;
        base_bounty_stable = _base_bounty_stable;
    }

    function stopOrder(uint256 _order_id)external nonReentrant {
        Order storage order = orders[_order_id];
        require(order.min_price > 0,"order dose not exist");
        require(order.status == OrderStatus.Open,"order not opened");
        require(orderToOwner[_order_id] == _msgSender(),"not your order");
        order.status = OrderStatus.Stop;
        //todo emit event
    }

    function closeOrder(uint256 _order_id)external nonReentrant {
        Order storage order = orders[_order_id];
        require(order.min_price > 0,"order dose not exist");
        require(orderToOwner[_order_id] == _msgSender(),"not your order");
        _closeOrder(order);
        _forceClosePosition(orderToTransaction[_order_id]);
        
    }

    function _closeOrder(Order storage order)internal {
        require(order.status != OrderStatus.Close,"order is closed");
        order.status = OrderStatus.Close;
        //todo emit event
        if(order.balance > 0){
            if(order.side == Side.Buy){
                IERC20(stable).transfer(_msgSender(),order.balance);
            }else{
                payable(_msgSender()).transfer(order.balance);
            }
        }
        order.balance = 0;
    }

    function _forceClosePosition(uint256[] memory _transaction_ids)internal {
        uint256 eth_amount;
        uint256 stable_amount;
        for(uint256 i = 0; i < _transaction_ids.length; ++i){
            Transaction storage transaction = transactions[_transaction_ids[i]];
            if(transaction.status == TxStatus.InPosition){
                if(transaction.side == Side.Buy){
                    eth_amount += transaction.amount - base_bounty_eth;
                    payable(transaction.creator).transfer(base_bounty_eth);
                }else{
                    stable_amount += transaction.amount - base_bounty_stable;
                    IERC20(stable).transfer(transaction.creator,base_bounty_stable);
                }
                transaction.status = TxStatus.Over;
                //todo emit event
            }
        }
        if(eth_amount > 0){
            payable(_msgSender()).transfer(eth_amount);
        }
        if(stable_amount > 0){
            IERC20(stable).transfer(_msgSender(),stable_amount);
        }
    }

 


    function closePosition(uint256 _transaction_id)external nonReentrant{
        Transaction storage transaction = transactions[_transaction_id];
        require(transaction.amount > 0,"position dose not exist");
        require(transaction.status == TxStatus.InPosition,"position has been close");
        uint256 current_price = _getEthPrice();
        Order storage order = orders[transaction.order_id];
        if(transaction.side == Side.Sell){
            require(current_price < transaction.cost_price - order.interval_price,
                                    "The current price is no longer in the closing range");
            uint256 eth_amount = _buy(transaction.amount);
            require(eth_amount > order.share_amount,"losing trade");
            uint256 income = eth_amount - order.share_amount;
            uint256 bounty = income * 200/1000;
            if(_msgSender() != transaction.creator){
                bounty = income * 100/1000;
            }
            payable(_msgSender()).transfer(bounty);
            order.last_price = transaction.amount/eth_amount;
            if(order.status == OrderStatus.Close){
                payable(orderToOwner[transaction.order_id]).transfer(eth_amount - bounty);
            }else {
                order.balance += eth_amount - bounty;
            }
        }else{
            require(current_price > transaction.cost_price - order.interval_price,
                                    "The current price is no longer in the closing range");
            uint256 stable_amount = _sell(transaction.amount);
            require(stable_amount > order.share_amount,"losing trade");
            uint256 income = stable_amount - order.share_amount;
            uint256 bounty = income * 200/1000;
            if(_msgSender() != transaction.creator){
                bounty = income * 100/1000;
            }
            IERC20(stable).transfer(_msgSender(),bounty);
            order.last_price = stable_amount/transaction.amount;

            if(order.status == OrderStatus.Close){
                IERC20(stable).transfer(orderToOwner[transaction.order_id],stable_amount - bounty);
            }else {
                order.balance += stable_amount - bounty;
            }
            order.balance += stable_amount - bounty;
        }

        transaction.status = TxStatus.Over;

        //todo emit event
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
        order.last_price = order.share_amount/eth_amount;

        transactions[transactions.length] = Transaction(
            Side.Buy,
            TxStatus.InPosition,
            _order_id,
            0,
            order.last_price,
            eth_amount,
            _msgSender()
        );
        orderToTransaction[_order_id].push(transactions.length - 1);

        //todo emit event
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
        order.last_price = stable_amount/order.share_amount;
        transactions[transactions.length] = Transaction(
            Side.Sell,
            TxStatus.InPosition,
            _order_id,
            0,
            order.last_price,
            stable_amount,
            _msgSender()
        );
        orderToTransaction[_order_id].push(transactions.length - 1);
         //todo emit event
    }

    function createGrid(
        Side side,
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _interval_price,
        uint256 _share_amount) payable external nonReentrant() {

        require(_interval_price >= interval_price_min,'price interval is too small');

        uint256 current_price = _getEthPrice();
        require(current_price  <= _max_price 
                && current_price  >= _min_price,'price range is too small');
        require(_share_amount <= _init_amount/grid_amount_min ,'too few grids');
        
        if(side == Side.Buy){
            _createBuyGrid(_min_price,_max_price,_init_amount,current_price,_interval_price,_share_amount);
        }else if (side == Side.Sell){
            _createSellGrid(_min_price,_max_price,0,current_price,_interval_price,_share_amount);
        }else{
            _createBuyAndSellGrid(_min_price,_max_price,_init_amount,_interval_price,_share_amount);
        }
    }




    function _createSellGrid(
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _init_price,
        uint256 _interval_price,
        uint256 _share_amount)internal{
        
        if(_init_amount == 0){
            _init_amount = msg.value;
        }
        require(_init_amount > 0,'need to put money in');
        // todo: set investment threshold

        orders[orders.length] = Order(
            Side.Sell,
            OrderStatus.Open,
            _min_price,
            _max_price,
            _init_amount,
            _init_price,
            _init_price,
            _interval_price,
            _share_amount,
            _init_amount
        );
        
        orderToOwner[orders.length - 1] = _msgSender();
        //todo emit Event
    }

    function _createBuyGrid(
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _init_price,
        uint256 _interval_price,
        uint256 _share_amount)internal{

        require(_init_amount > 0,'need to put money in');
        // todo: set investment threshold

        IERC20(stable).transferFrom(_msgSender(),address(this),_init_amount);
        orders[orders.length] = Order(
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
        );
        
        orderToOwner[orders.length - 1] = _msgSender();
        //todo emit Event
    }

    function _createBuyAndSellGrid(
        uint256 _min_price,
        uint256 _max_price,
        uint256 _init_amount,
        uint256 _interval_price,
        uint256 _share_amount)internal{

        require(_init_amount > 0,'need to put money in');
        // todo: set investment threshold

        IERC20(stable).transferFrom(_msgSender(),address(this),_init_amount);

        uint256 receive_amount = _buy(_init_amount/2);
        uint256 eth_price = _init_amount/2/receive_amount;
        _createBuyGrid(_min_price,_max_price,_init_amount/2,eth_price,_interval_price,_share_amount);
        uint256 eth_share_amount = _share_amount/eth_price;
        _createSellGrid(_min_price,_max_price,receive_amount,eth_price,_interval_price,eth_share_amount);
    }
    

    function _getEthPrice()internal returns (uint256 price){

    }

    function _buy(uint256 amount)internal returns (uint256 receive_amount){
        uint256 eth_balance_before = address(this).balance;
        //todo _swap()
        uint256 eth_balance_after = address(this).balance;
        receive_amount = eth_balance_after - eth_balance_before;
    }

    function _sell(uint256 amount)internal returns(uint256 receive_amount){
        uint256 stable_balance_before = IERC20(stable).balanceOf(address(this));
        //todo _swap()
        uint256 stable_balance_after = IERC20(stable).balanceOf(address(this));
        receive_amount = stable_balance_after - stable_balance_before;
    }

}