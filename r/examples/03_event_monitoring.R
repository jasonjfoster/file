# Event monitoring for a watchlist
#
# The third most common workflow: track material events by retrieving
# current report ("8-K") filing metadata for a watchlist of filers over
# a recent date range.
#
# Pipeline: get_ciks -> get_submissions

library(secfile)

user_agent <- "username@domain.com"

# explore the available item numbers
# (e.g., "2.02" is results of operations and financial condition and
# "5.02" is officer departures and appointments)
print(data_items)

# watchlist of filers by ticker
ciks <- get_ciks(c("AAPL", "MSFT", "TSLA"), user_agent = user_agent)

# current report filings over a recent date range
submissions <- get_submissions(ciks, forms = "8-K", from_date = "2025-01-01",
                               user_agent = user_agent)

# the items column contains the 8-K item numbers for each filing
# (see `data_items`)
print(submissions[ , intersect(c("cik", "filingDate", "items", "url"),
                               colnames(submissions))])

# filter to results announcements
results <- submissions[which(grepl("2.02", submissions[["items"]], fixed = TRUE)), ]
print(results[ , intersect(c("cik", "filingDate", "items", "url"),
                           colnames(results))])
