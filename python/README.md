# file

[![codecov](https://codecov.io/github/jasonjfoster/file/graph/badge.svg?token=ZQ1ML6FMEW)](https://codecov.io/github/jasonjfoster/file)

## Overview

'secfile' provides simple and efficient access to the SEC's 'EDGAR' APIs <https://www.sec.gov/search-filings> for querying and retrieving filings.

The 'secfile' package abstracts the complexities of interacting with SEC EDGAR APIs, such as session management, user agent declaration, rate limiting, index parsing, pagination of filing metadata, URL construction, document caching, and inline XBRL parsing. This abstraction allows users to focus on retrieving data rather than managing API details. Use cases include retrieving filings across a range of workflows:

* **Indexes**: master index of all filings by form type and date for universe construction
* **Tenures**: status windows built by pairing entry and exit form filings
* **Submissions**: filing metadata for any filer with form type and date range filters
* **Facts**: investment-level or company-level facts extracted from inline XBRL filings

The package supports flexible query capabilities, including customizable form types, date ranges, and dimensions, and automatic data validation. It handles the SEC's fair access requirements automatically, such as user agent declaration and rate limiting between requests, and caches downloaded documents for efficient retrieval of large datasets.

The implementation uses standard HTTP libraries to handle API interactions efficiently and is available in both R and 'Python' for accessibility to a broad audience.

## Installation

* Install the released version from PyPI:

```python
pip install secfile
```

* Or the development version from GitHub:

```python
pip install git+https://github.com/jasonjfoster/file.git@main#subdirectory=python
```

## Usage

First, import the package and explore the available form types, which are sourced from the SEC EDGAR form types data <https://www.sec.gov/Archives/edgar/lookup-data.js>:

```python
import secfile as sec

print(sec.data_forms)
```

The SEC requires a user agent that declares contact information for fair access. The package identifies itself by default, but pass the `user_agent` argument to identify the user:

```python
user_agent = "username@domain.com"
```

Next, to look up the Central Index Key ("CIK") for one or more tickers, use the `get_ciks()` method:

```python
ciks = sec.get_ciks(["AAPL", "MSFT"], user_agent = user_agent)
```

Then, to retrieve filing metadata for one or more filers, use the `get_submissions()` method. By default, the method retrieves annual ("10-K") and quarterly ("10-Q") report filings:

```python
submissions = sec.get_submissions(ciks, forms = "10-K", from_date = "2024-01-01",
                                  user_agent = user_agent)
```

Finally, retrieve facts from inline XBRL filings using the `get_data()` method. By default, the method returns all contexts that match the report date of each filing, and the result contains the period type, start and end dates, dimension axes and members, and facts for each context:

```python
data = sec.get_data(submissions, cache_dir = "cache", user_agent = user_agent)
```

See the [examples](examples/) directory for complete workflows, including company-level fundamentals, survivorship-bias-free universe construction, and material event monitoring.
