# Company-level fundamentals
#
# The most common workflow: retrieve annual ("10-K") and quarterly ("10-Q")
# report filings for one or more known filers, then extract company-level
# facts from the inline XBRL filings.
#
# Pipeline: get_ciks -> get_submissions -> get_data

import secfile as sec

# the sec requires a user agent that declares contact information
# (e.g., "username@domain.com") for fair access
user_agent = "username@domain.com"

# explore the available form types
print(sec.data_forms)

# 1. central index key ("cik") for one or more tickers
ciks = sec.get_ciks(["AAPL", "MSFT"], user_agent = user_agent)

print(ciks)

# 2. filing metadata for one or more filers
#    ("10-K" and "10-Q" filings by default)
submissions = sec.get_submissions(ciks, forms = "10-K", from_date = "2023-01-01",
                                  user_agent = user_agent)

print(submissions[["cik", "form", "filingDate", "reportDate", "url"]])

# 3. facts from inline xbrl filings
#    (all contexts that match the report date of each filing by default)
data = sec.get_data(submissions, cache_dir = "cache", user_agent = user_agent)

# each row is a context: the period type, start and end dates, dimension
# axes and members, and facts (e.g., revenue, assets) as columns
print(data[["cik", "report_date", "period_type", "period_start", "period_end"]])

# company-level totals are the contexts without dimensions; balance-sheet
# facts are reported for a point in time ("instant" contexts), while
# duration contexts carry income-statement facts instead
totals = data[(data["axis"] == "") & (data["period_type"] == "instant")]
print(totals.filter(["cik", "report_date", "Assets", "Liabilities",
                     "StockholdersEquity"]))
