# file

## Version 0.1.0

* Generalized the `get_data()` method to match duration contexts (e.g., fiscal period facts) in addition to instant contexts and to capture all dimension axes and members for each context
* Added period type, start and end dates, and dimension axis and member columns to the result of the `get_data()` method
* Changed the `dimension` argument to accept an axis name (e.g., "InvestmentIdentifierAxis") in addition to "typed", "explicit", or `None`
* Added the `get_ciks()` method to look up the Central Index Key ("CIK") for one or more tickers from <https://www.sec.gov/files/company_tickers.json>
* Added session caching by user agent to the `get_session()` method to reuse connections across method calls
* Changed defaults to support the company-level workflow: the `get_index()` method defaults to annual ("10-K") and quarterly ("10-Q") report filings, the `create_tenures()` method requires the entry and exit forms, and the `get_data()` method defaults to all contexts
