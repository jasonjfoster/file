# test arguments
test_year <- 2006 # both "8-A12B" and "25" are filed electronically (2005 onward)
test_tickers <- list("AAPL", c("AAPL", "MSFT"), c("AAPL", "MSFT", "AMZN"))
test_forms <- c("10-K", "10-Q")
test_forms_events <- "8-K"
test_dates <- c("2023-01-01", "2023-12-31")
test_dimensions <- list(NULL, "typed", "explicit", "StatementEquityComponentsAxis")
test_user_agent <- "username@domain.com"

# the first year is the smallest index
test_indexes <- list(
  "all forms" = list(from_year = test_year, forms = NULL),
  "first year" = list(from_year = 1993, forms = test_forms[1]),
  "tenure forms" = list(from_year = test_year, forms = c("8-A12B", "25", "25-NSE"))
)

# registrations are filed under section 12(b) ("8-A12B") or 12(g) ("8-A12G");
# removals are filed by the issuer ("25") or the exchange ("25-NSE")
test_tenures <- list(
  "entry_form, exit_form" = list(entry_form = "8-A12B", exit_form = "25"),
  "entry_form, exit_forms" = list(entry_form = "8-A12B", exit_form = c("25", "25-NSE")),
  "entry_forms, exit_forms" = list(entry_form = c("8-A12B", "8-A12G"), exit_form = c("25", "25-NSE"))
)

# test data

# aligned (shared columns) and misaligned (missing columns, mixed
# types, and zero rows) data frames
test_aligns <- list(
  "columns" = list(
    dfs = list(
      data.frame(
        filingDate = as.Date("2023-01-01"),
        form = "10-K",
        stringsAsFactors = FALSE
      ),
      data.frame(
        filingDate = as.Date("2023-01-02"),
        form = "10-Q",
        stringsAsFactors = FALSE
      )
    ),
    expected = data.frame(
      filingDate = as.Date(c("2023-01-01", "2023-01-02")),
      form = c("10-K", "10-Q"),
      stringsAsFactors = FALSE
    )
  ),
  "fill" = list(
    dfs = list(
      data.frame(
        filingDate = as.Date(c("2023-01-01", "2023-01-02")),
        size = c(100L, 200L),
        form = c("10-K", "10-Q"),
        stringsAsFactors = FALSE
      ),
      data.frame(
        filingDate = as.Date("2023-01-03"),
        form = "8-K",
        "us-gaap:Assets" = "1000",
        check.names = FALSE,
        stringsAsFactors = FALSE
      ),
      data.frame(
        filingDate = as.Date(character(0))
      )
    ),
    expected = data.frame(
      filingDate = as.Date(c("2023-01-01", "2023-01-02", "2023-01-03")),
      size = c(100L, 200L, NA),
      form = c("10-K", "10-Q", "8-K"),
      "us-gaap:Assets" = c(NA, NA, "1000"),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  )
)

test_check_index <- data.frame(
  company = c("A", "A"),
  cik = c("1", "1"),
  form = c("8-A12B", "25"),
  date = as.Date(c("2006-01-01", "2006-12-31")),
  link = c("a", "b"),
  stringsAsFactors = FALSE
)
