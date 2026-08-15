test_that("valid 'forms', 'tickers', 'ciks', and 'dimension'", {

  # skip("long-running test")

  count <- 0
  result_ls <- list()
  errors_ls <- list()

  index <- tryCatch({
    get_index(from_year = test_year, to_year = test_year, forms = NULL,
              user_agent = test_user_agent)
  }, error = function(e) {
    data.frame()
  })

  if (length(index) == 0) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "get_index",
      value = "forms"
    )))

  } else {

    # amendments are filed with an "/A" suffix (e.g., "10-K/A")
    forms_live <- sub("/A$", "", toupper(index[["form"]]))
    forms_data <- toupper(secfile::data_forms[["form"]])

    forms_na <- setdiff(forms_live, forms_data)

    for (form in sort(forms_na)) {

      errors_ls <- append(errors_ls, list(data.frame(
        call = "get_index",
        value = form
      )))

    }

  }

  # the first year is the smallest index
  response <- tryCatch({

    index_form <- get_index(from_year = 1993, to_year = 1993, forms = test_forms[1],
                            user_agent = test_user_agent)

    if (length(index_form) > 0) {
      "success"
    } else {
      NULL
    }

  }, error = function(e) {
    NULL
  })

  if (is.null(response)) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "get_index",
      value = test_forms[1]
    )))

  }

  tenures <- data.frame()

  response <- tryCatch({

    tenures <- create_tenures(index, "8-A12B", "25")

    if (length(tenures) > 0) {
      "success"
    } else {
      NULL
    }

  }, error = function(e) {
    NULL
  })

  if (is.null(response)) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "create_tenures",
      value = "entry_form, exit_form"
    )))

  }

  # registrations are filed under section 12(b) ("8-A12B") or 12(g) ("8-A12G");
  # removals are filed by the issuer ("25") or the exchange ("25-NSE")
  response <- tryCatch({

    tenures_vector <- create_tenures(index, c("8-A12B", "8-A12G"),
                                     c("25", "25-NSE"))

    if (nrow(tenures_vector) >= nrow(tenures)) {
      "success"
    } else {
      NULL
    }

  }, error = function(e) {
    NULL
  })

  if (is.null(response)) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "create_tenures",
      value = "entry_forms, exit_forms"
    )))

  }

  ciks <- data.frame()

  for (tickers in test_tickers) {

    response <- tryCatch({

      ciks <- get_ciks(tickers, user_agent = test_user_agent)

      if (length(ciks) > 0) {
        "success"
      } else {
        NULL
      }

    }, error = function(e) {
      NULL
    })

    if (is.null(response)) {

      errors_ls <- append(errors_ls, list(data.frame(
        call = "get_ciks",
        value = paste(tickers, collapse = ", ")
      )))

    }

    count <- count + 1

    if (count %% 5 == 0) {

      message("pause one second after five requests")
      Sys.sleep(1)

    }

  }

  submissions <- data.frame()

  response <- tryCatch({

    submissions <- get_submissions(ciks, forms = test_forms,
                                   from_date = test_dates[1], to_date = test_dates[2],
                                   user_agent = test_user_agent)

    if (length(submissions) > 0) {
      "success"
    } else {
      NULL
    }

  }, error = function(e) {
    NULL
  })

  if (is.null(response)) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "get_submissions",
      value = "ciks"
    )))

  }

  response <- tryCatch({

    cik <- ciks[["cik"]][1]

    submissions_cik <- get_submissions(cik, forms = test_forms[1],
                                       from_date = test_dates[1], to_date = test_dates[2],
                                       user_agent = test_user_agent)

    if (length(submissions_cik) > 0) {
      "success"
    } else {
      NULL
    }

  }, error = function(e) {
    NULL
  })

  if (is.null(response)) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "get_submissions",
      value = "cik"
    )))

  }

  submissions_tenures <- data.frame()

  # tenures with a missing start date (no lower bound), a missing end date
  # (no upper bound), and closed (both dates)
  response <- tryCatch({

    tenures_na <- rbind(
      head(tenures[is.na(tenures[["start_date"]]), ], 1),
      head(tenures[is.na(tenures[["end_date"]]), ], 1),
      head(tenures[!is.na(tenures[["start_date"]]) & !is.na(tenures[["end_date"]]), ], 1)
    )

    submissions_tenures <- get_submissions(tenures_na, forms = NULL,
                                           user_agent = test_user_agent)

    if (length(submissions_tenures) > 0) {
      "success"
    } else {
      NULL
    }

  }, error = function(e) {
    NULL
  })

  if (is.null(response)) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "get_submissions",
      value = "tenures"
    )))

  }

  if (length(submissions_tenures) > 0) {

    items_live <- submissions_tenures[["items"]]
    items_live[is.na(items_live)] <- ""
    items_live <- trimws(unlist(strsplit(items_live, ",", fixed = TRUE)))
    items_live <- items_live[nzchar(items_live)]
    items_data <- secfile::data_items[["item"]]

    items_na <- setdiff(items_live, items_data)

    for (item in sort(items_na)) {

      errors_ls <- append(errors_ls, list(data.frame(
        call = "get_submissions",
        value = item
      )))

    }

  }

  if (length(submissions) > 0) {
    submissions_xbrl <- submissions[which(toupper(submissions[["form"]]) == test_forms[1]), ]
  } else {
    submissions_xbrl <- data.frame()
  }

  cache_dir <- file.path(tempdir(), "cache")

  # reuse the cached documents after the first pass
  for (dimension in test_dimensions) {

    response <- tryCatch({

      data <- get_data(submissions_xbrl, dimension = dimension, cache_dir = cache_dir,
                       user_agent = test_user_agent)

      response <- "success"

      # a specific axis may be absent from the filing
      if (is.null(dimension) && (length(data) == 0)) {
        response <- NULL
      }

      response

    }, error = function(e) {
      NULL
    })

    if (is.null(response)) {

      if (is.null(dimension)) {
        value <- NA
      } else {
        value <- dimension
      }

      errors_ls <- append(errors_ls, list(data.frame(
        call = "get_data",
        value = value
      )))

    }

  }

  response <- tryCatch({

    date <- as.character(as.Date(submissions_xbrl[["reportDate"]][1]))

    data <- get_data(submissions_xbrl, date = date, cache_dir = cache_dir,
                     user_agent = test_user_agent)

    if (length(data) > 0) {
      "success"
    } else {
      NULL
    }

  }, error = function(e) {
    NULL
  })

  if (is.null(response)) {

    errors_ls <- append(errors_ls, list(data.frame(
      call = "get_data",
      value = "date"
    )))

  }

  unlink(cache_dir, recursive = TRUE)

  if (length(errors_ls) > 0) {

    result <- do.call(rbind, errors_ls)
    result_ls <- append(result_ls, list(result))

  }

  expect_equal(result_ls, list())

})
