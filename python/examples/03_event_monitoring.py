# Event monitoring for a watchlist
#
# The third most common workflow: track material events by retrieving
# current report ("8-K") filing metadata for a watchlist of filers over
# a recent date range.
#
# Pipeline: get_ciks -> get_submissions

import secfile as sec

user_agent = "username@domain.com"

# explore the available item numbers
# (e.g., "2.02" is results of operations and financial condition and
# "5.02" is officer departures and appointments)
print(sec.data_items)

# watchlist of filers by ticker
ciks = sec.get_ciks(["AAPL", "MSFT", "TSLA"], user_agent = user_agent)

# current report filings over a recent date range
submissions = sec.get_submissions(ciks, forms = "8-K", from_date = "2025-01-01",
                                  user_agent = user_agent)

# the items column contains the 8-K item numbers for each filing
# (see `data_items`)
print(submissions.filter(["cik", "filingDate", "items", "url"]))

# filter to results announcements
results = submissions[submissions["items"].str.contains("2.02", regex = False, na = False)]
print(results.filter(["cik", "filingDate", "items", "url"]))
