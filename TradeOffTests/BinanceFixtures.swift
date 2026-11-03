import Foundation

enum BinanceFixtures {
    static let tickers24h = #"""
[{"symbol":"BTCUSDT","priceChange":"-988.00000000","priceChangePercent":"-1.265","weightedAvgPrice":"77749.16136989","prevClosePrice":"78128.01000000","lastPrice":"77140.00000000","lastQty":"0.01368000","bidPrice":"77140.00000000","bidQty":"0.01215000","askPrice":"77140.01000000","askQty":"10.92376000","openPrice":"78128.00000000","highPrice":"78878.01000000","lowPrice":"76663.90000000","volume":"12683.03884000","quoteVolume":"986095633.43168120","openTime":1793580380013,"closeTime":1793666780013,"firstId":6810498700,"lastId":6813567993,"count":3069294},{"symbol":"ETHUSDT","priceChange":"-12.62000000","priceChangePercent":"-0.556","weightedAvgPrice":"2283.47497947","prevClosePrice":"2271.38000000","lastPrice":"2258.76000000","lastQty":"0.00240000","bidPrice":"2258.75000000","bidQty":"0.55660000","askPrice":"2258.76000000","askQty":"101.47150000","openPrice":"2271.38000000","highPrice":"2317.84000000","lowPrice":"2237.38000000","volume":"244823.18540000","quoteVolume":"559047618.25586600","openTime":1793580380014,"closeTime":1793666780014,"firstId":4481666926,"lastId":4483566542,"count":1899617}]
"""#

    static let klines = #"""
[[1793491200000,"77582.02000000","78422.23000000","77517.20000000","78354.00000000","6544.36057000",1793577599999,"510160451.25306300",1147208,"3400.27887000","265079668.66308800","0"],[1793577600000,"78354.01000000","78878.01000000","76705.00000000","76816.00000000","12640.71498000",1793663999999,"983243310.74426500",3069431,"7081.31172000","550788542.88558390","0"],[1793664000000,"76816.01000000","77253.58000000","76663.90000000","77096.01000000","422.12808000",1793750399999,"32500634.62950630",98313,"223.93209000","17240408.74725340","0"]]
"""#

    static let exchangeInfo = #"""
{"timezone":"UTC","serverTime":1793666780013,"symbols":[{"symbol":"BTCUSDT","status":"TRADING","baseAsset":"BTC","quoteAsset":"USDT","isSpotTradingAllowed":true},{"symbol":"PEPEUSDT","status":"TRADING","baseAsset":"PEPE","quoteAsset":"USDT","isSpotTradingAllowed":true},{"symbol":"ETHBTC","status":"TRADING","baseAsset":"ETH","quoteAsset":"BTC","isSpotTradingAllowed":true},{"symbol":"USDCUSDT","status":"TRADING","baseAsset":"USDC","quoteAsset":"USDT","isSpotTradingAllowed":true},{"symbol":"LUNAUSDT","status":"BREAK","baseAsset":"LUNA","quoteAsset":"USDT","isSpotTradingAllowed":true},{"symbol":"WIFUSDT","status":"TRADING","baseAsset":"WIF","quoteAsset":"USDT","isSpotTradingAllowed":true},{"symbol":"SOLUSDT","status":"TRADING","baseAsset":"SOL","quoteAsset":"USDT","isSpotTradingAllowed":true},{"symbol":"SOLVUSDT","status":"TRADING","baseAsset":"SOLV","quoteAsset":"USDT","isSpotTradingAllowed":true}],"rateLimits":[]}
"""#

    static let bookMessage = #"""
{"stream":"btcusdt@bookTicker","data":{"u":400900217,"s":"BTCUSDT","b":"77150.10000000","B":"31.21000000","a":"77150.20000000","A":"40.66000000"}}
"""#

    static let miniMessage = #"""
{"stream":"btcusdt@miniTicker","data":{"e":"24hrMiniTicker","E":1793666790000,"s":"BTCUSDT","c":"77155.50000000","o":"78128.00000000","h":"78878.01000000","l":"76663.90000000","v":"12683.03884000","q":"986095633.43168120"}}
"""#
}
