# Filing index for bulk and historical research
#
# The second most common workflow: build a universe of filings from the
# master index by form type and date for bulk download or historical
# research, then refine the universe to a point in time by pairing entry
# and exit form filings ("tenures").
#
# Pipeline: get_index -> create_tenures

library(secfile)

user_agent <- "username@domain.com"

# reuse one session across function calls
session <- get_session(user_agent)

# 1. master index of filings by form type and date
#    (each year requests four quarterly index files, so narrow the year
#    range while iterating)
index <- get_index(from_year = 2024, to_year = 2024, forms = "10-K",
                   session = session)

# each row is a filing: the company, cik, form, date, and link
print(index)

# filings by quarter
print(table(quarters(index[["date"]])))

# the link column contains the archives url for each filing document
print(head(index[["link"]]))

# 2. refine the universe to a point in time: pair exchange listing
#    registration ("8-A12B") and removal ("25") filings to build listing
#    status windows for survivorship-bias-free universes
#    (use from_year = 1993 for the full history)
index <- get_index(from_year = 2024, forms = c("8-A12B", "25"),
                   session = session)

tenures <- create_tenures(index, "8-A12B", "25")

# filers listed as of a point in time: the end date is missing for
# active listings
as_of <- "2024-06-30"
listed <- tenures[which((tenures[["start_date"]] <= as_of) &
                        (is.na(tenures[["end_date"]]) | (tenures[["end_date"]] > as_of))), ]

print(listed[ , c("company", "cik", "start_date", "end_date")])
