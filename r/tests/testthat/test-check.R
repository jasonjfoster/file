test_that("input checks", {

  # test data
  test_check_index <- data.frame(
    company = c("A", "A"),
    cik = c("1", "1"),
    form = c("8-A12B", "25"),
    date = as.Date(c("2006-01-01", "2006-12-31")),
    link = c("a", "b"),
    stringsAsFactors = FALSE
  )
  test_check_ciks <- "320193"

  # check_user_agent
  expect_error(get_session("username"),
               "invalid 'user_agent'")

  # check_year: 'from_year'
  expect_error(get_index(from_year = "2006"),
               "invalid 'from_year'")
  expect_error(get_index(from_year = 1992),
               "value of 'from_year' must be greater than or equal to 1993")

  # check_years
  expect_error(get_index(from_year = 2006, to_year = 2005),
               "value of 'to_year' must be greater than or equal to value of 'from_year'")

  # check_forms
  expect_error(get_index(forms = ""),
               "invalid 'forms'")

  # check_tenures: 'entry_form'
  expect_error(create_tenures(test_check_index, "", "25"),
               "invalid 'entry_form'")

  # check_tenures: 'exit_form'
  expect_error(create_tenures(test_check_index, "8-A12B", ""),
               "invalid 'exit_form'")

  # check_tenures: 'exit_form' (equal to 'entry_form')
  expect_error(create_tenures(test_check_index, "8-A12B", "8-a12b"),
               "values of 'exit_form' must not equal values of 'entry_form'")

  # check_tickers
  expect_error(get_ciks(""),
               "invalid 'tickers'")

  # check_forms
  expect_error(get_submissions(test_check_ciks, forms = NA),
               "invalid 'forms'")

  # check_date: 'from_date'
  expect_error(get_submissions(test_check_ciks, from_date = "2023-13-01"),
               "invalid 'from_date'")

  # check_dates
  expect_error(get_submissions(test_check_ciks, from_date = "2023-12-31", to_date = "2023-01-01"),
               "value of 'to_date' must be greater than or equal to value of 'from_date'")

  # check_ciks
  expect_error(get_submissions("abc"),
               "invalid 'ciks'")

  # check_dimension
  expect_error(get_data(data.frame(), dimension = c("a", "b")),
               "invalid 'dimension'")

})
