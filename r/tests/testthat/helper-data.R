test_year <- 2006 # both "8-A12B" and "25" are filed electronically (2005 onward)
test_tickers <- list("AAPL", c("AAPL", "MSFT"), c("AAPL", "MSFT", "AMZN"))
test_forms <- c("10-K", "10-Q")
test_dates <- c("2023-01-01", "2023-12-31")
test_dimensions <- list(NULL, "typed", "explicit", "StatementEquityComponentsAxis")
test_user_agent <- "username@domain.com"

# aligned (shared columns) and misaligned (missing columns, mixed
# types, and zero rows) data frames
test_aligns <- list(
  list(
    value = "columns",
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
  list(
    value = "fill",
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
