## 想法：一个链上网格交易合约

todo list
```
1,关闭订单（提现）,
    1,未平仓仓位如何处理
2,创建订单时设置赏金比例
3,开放所有交易对，不固定为usds/eth
```
1,创建网格动作情况分析：
```shell
    1）usdc:100%,eth:0%
        不做其他处理，记录当前价格，如果价格下跌到买点就买入
        order{
            min_price: 1400;
            max_price: 2200;
            init_eth_amount: 0;
            init_stable_amount: 10000;
            init_price: 1800;
            interval_price: 50;
            grid_amount: 10;
        }
        1.if price = 1855 // eth:0/usdc:10000  no position
        2.if price = 1745 // buy 1000 usdc => eth:0.573/usdc:9000 
                            position[
                                {
                                    id: 1;
                                    type: buy;
                                    price: 1745;
                                    spend: 1000;
                                    receive: 0.573;
                                    isOver: flase;
                                }
                            ]
        3.if price = 1688 // buy 1000 usdc => eth:1.165/usdc:8000
                            position[
                                {
                                    id: 1;
                                    type: buy;
                                    price: 1745;
                                    spend: 1000;
                                    receive: 0.573;
                                    isOver: flase;
                                },
                                {
                                    id: 2;
                                    type: buy;
                                    price: 1688;
                                    spend: 1000;
                                    receive: 0.592;
                                    isOver: flase;
                                }
                            ]
        4.if price = 1744 // sell 0.592 eth => eth:0.573/usdc:9032.448

    2）usdc:0%,eth:100%
        不做其他处理，记录当前价格，如果价格上涨到卖点就卖出
    3）usdc:30%,eth:70%
        不做其他处理，记录当前价格，如果价格上涨到卖点就卖出
```