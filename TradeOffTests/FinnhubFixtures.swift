import Foundation

enum FinnhubFixtures {
    static let quote = #"""
{"c":261.74,"d":2.29,"dp":0.8826,"h":263.31,"l":260.68,"o":261.07,"pc":259.45,"t":1582641000}
"""#

    static let unknownQuote = #"""
{"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0}
"""#

    static let search = #"""
{"count":7,"result":[{"description":"APPLE INC","displaySymbol":"AAPL","symbol":"AAPL","type":"Common Stock"},{"description":"APPLE INC","displaySymbol":"AAPL.SW","symbol":"AAPL.SW","type":"Common Stock"},{"description":"APPLE HOSPITALITY REIT INC","displaySymbol":"APLE","symbol":"APLE","type":"Common Stock"},{"description":"ISHARES CORE S&P 500 ETF","displaySymbol":"IVV","symbol":"IVV","type":"ETP"},{"description":"APPLE INC - ADR","displaySymbol":"APC","symbol":"APCSY","type":"ADR"},{"description":"APPLE INC","displaySymbol":"AAPL","symbol":"AAPL","type":"Common Stock"},{"description":"BROKEN"}]}
"""#

    static let liveQuote = #"""
{"c":338.32,"d":-6.31,"dp":-1.8309,"h":343.8,"l":335.82,"o":342.67,"pc":344.63,"t":1793653200}
"""#

    static let liveSearch = #"""
{"count":11,"result":[{"description":"Apple Inc.","displaySymbol":"AAPL","symbol":"AAPL","type":"Common Stock"},{"description":"Apple Hospitality REIT Inc","displaySymbol":"APLE","symbol":"APLE","type":"Common Stock"},{"description":"Apple Flavor & Fragrance Group Co Ltd","displaySymbol":"603020.SS","symbol":"603020.SS","type":"Common Stock"},{"description":"Maui Land & Pineapple Company Inc","displaySymbol":"MLP","symbol":"MLP","type":"Common Stock"},{"description":"Apple iSports Group Inc","displaySymbol":"AAPI","symbol":"AAPI","type":"Common Stock"},{"description":"Apple International Co Ltd","displaySymbol":"2788.T","symbol":"2788.T","type":"Common Stock"},{"description":"Pineapple Financial Inc","displaySymbol":"PAPL","symbol":"PAPL","type":"Common Stock"},{"description":"Applepark Co Ltd","displaySymbol":"164A.T","symbol":"164A.T","type":"Common Stock"},{"description":"Pineapple Resources Bhd","displaySymbol":"PINEAPP.KL","symbol":"PINEAPP.KL","type":"Common Stock"},{"description":"Pineapple Energy Inc","displaySymbol":"SUNE","symbol":"SUNE","type":"Common Stock"},{"description":"Pineapple Power Corporation PLC","displaySymbol":"PNPL.L","symbol":"PNPL.L","type":"Common Stock"}]}
"""#
}
