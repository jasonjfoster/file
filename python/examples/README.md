# Examples

The examples in this directory demonstrate common workflows for the 'secfile' package, ordered by the most common use cases across the SEC EDGAR ecosystem: financial statement analysis first, bulk filing collection second, and event monitoring third.

| Example | Workflow | Pipeline |
|---|---|---|
| [`01_company_fundamentals.py`](01_company_fundamentals.py) | Company-level facts for known filers (financial research and modeling) | `get_ciks` → `get_submissions` → `get_data` |
| [`02_filing_index.py`](02_filing_index.py) | Filing universe by form type and date (bulk and historical research), refined to a point in time with tenures | `get_index` → `create_tenures` |
| [`03_event_monitoring.py`](03_event_monitoring.py) | Material event ("8-K") tracking for a watchlist | `get_ciks` → `get_submissions` |

## Notes

* **Tickers**: use the `get_ciks()` method to look up the Central Index Key ("CIK") for one or more tickers. Filers without a listed ticker (e.g., non-traded funds) must be identified by CIK or through the master index.
* **User agent**: the SEC requires a user agent that declares contact information (e.g., `"username@domain.com"`) for fair access. Replace the placeholder in each example. The SEC returns a 403 error for user agents that contain a URL, impersonate a browser, or omit contact information.
* **Sessions**: pass `session = sec.get_session(user_agent)` to reuse a connection across method calls; when a session is provided, the `user_agent` argument is ignored. Sessions are also cached by user agent automatically.
* **Rate limiting**: the package pauses one second after every five requests automatically. Full-history index builds (`from_year = 1993`) request four quarterly files per year, so narrow the year range while iterating.
* **Caching**: pass the `cache_dir` argument to the `get_data()` method to cache downloaded XBRL instance documents (gzip-compressed) so repeated runs over large datasets only download new filings.

## Dimensions in `get_data()`

The `dimension` argument controls which XBRL contexts are returned:

* `None` (default): all contexts that match the report date; company-level totals are the rows where `axis` is empty
* `"typed"` or `"explicit"`: contexts with at least one typed or explicit member
* An axis name (e.g., `"InvestmentIdentifierAxis"`): contexts on that axis, with or without the namespace prefix

## Scope

The `get_data()` method parses inline XBRL instance documents, the format used by financial reports (e.g., "10-K", "10-Q", "20-F", "N-CSR"). Filings that attach structured data as separate XML documents, such as insider transactions ("3", "4", "5") and fund holdings ("13F-HR", "NPORT-P"), are not parsed by the `get_data()` method, although their filing metadata and document URLs are available through the `get_index()` and `get_submissions()` methods.
