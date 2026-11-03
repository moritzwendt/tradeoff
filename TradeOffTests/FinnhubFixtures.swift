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

    static let candles = #"""
{"c":[264.1,264.5,262.2,262.9],"h":[264.3,264.7,262.6,263.1],"l":[263.8,264.0,261.9,262.1],"o":[263.9,264.1,262.0,262.3],"s":"ok","t":[1793367000,1793367300,1793629800,1793630100],"v":[120345,98213,200144,150320]}
"""#
}
