# file

## Overview

'file' provides simple and efficient access to the SEC's 'EDGAR' APIs <https://www.sec.gov/search-filings> for querying and retrieving filings.

The 'file' package abstracts the complexities of interacting with SEC EDGAR APIs, such as session management, user agent declaration, rate limiting, index parsing, pagination of filing metadata, URL construction, document caching, and inline XBRL parsing. This abstraction allows users to focus on retrieving data rather than managing API details. Use cases include retrieving filings across a range of workflows:

* **Indexes**: master index of all filings by form type and date for universe construction
* **Tenures**: status windows built by pairing entry and exit form filings
* **Submissions**: filing metadata for any filer with form type and date range filters
* **Facts**: investment-level or company-level facts extracted from inline XBRL filings

The package supports flexible query capabilities, including customizable form types, date ranges, and dimensions, and automatic data validation. It handles the SEC's fair access requirements automatically, such as user agent declaration and rate limiting between requests, and caches downloaded documents for efficient retrieval of large datasets.

The implementation uses standard HTTP libraries to handle API interactions efficiently and is available in both R and 'Python' for accessibility to a broad audience.
