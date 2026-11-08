test_that("valid 'forms', 'tickers', 'ciks', and 'dimension'", {

  skip_on_cran()

  count <- 0
  result_ls <- list()
  errors_ls <- list()

  index_ls <- list()

  for (name in names(test_indexes)) {

    args <- test_indexes[[name]]
    from_year <- args[["from_year"]]
    forms <- args[["forms"]]

    index_ls[[name]] <- data.frame()

    response <- tryCatch({

      index_ls[[name]] <- get_index(from_year = from_year, to_year = from_year, forms = forms,
                                    user_agent = test_user_agent)

      # the forms filter returns only the requested form types
      if ((length(index_ls[[name]]) > 0) &&
          (is.null(forms) || all(toupper(index_ls[[name]][["form"]]) %in% forms))) {
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
        value = name
      )))

    }

  }

  index <- index_ls[["all forms"]]

  if (length(index) > 0) {

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

  tenures_ls <- list()

  for (name in names(test_tenures)) {

    args <- test_tenures[[name]]
    entry_form <- args[["entry_form"]]
    exit_form <- args[["exit_form"]]

    tenures_ls[[name]] <- data.frame()

    response <- tryCatch({

      tenures_ls[[name]] <- create_tenures(index, entry_form, exit_form)

      if (length(tenures_ls[[name]]) > 0) {
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
        value = name
      )))

    }

  }

  tenures <- tenures_ls[["entry_form, exit_form"]]

  # more form types match at least as many tenures and the forms filter agrees
  response <- tryCatch({

    tenures_forms <- create_tenures(index_ls[["tenure forms"]], "8-A12B", c("25", "25-NSE"))

    if (!is.unsorted(vapply(tenures_ls, nrow, integer(1))) &&
        (nrow(tenures_forms) == nrow(tenures_ls[["entry_form, exit_forms"]]))) {
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
      value = "forms"
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

  # tenures with a missing start date (no lower bound), a missing end date
  # (no upper bound), and closed (both dates)
  tenures_na <- tryCatch({

    rbind(
      head(tenures[is.na(tenures[["start_date"]]), ], 1),
      head(tenures[is.na(tenures[["end_date"]]), ], 1),
      head(tenures[!is.na(tenures[["start_date"]]) & !is.na(tenures[["end_date"]]), ], 1)
    )

  }, error = function(e) {
    data.frame()
  })

  test_submissions <- list(
    "ciks" = list(ciks = ciks, forms = test_forms,
                  from_date = test_dates[1], to_date = test_dates[2]),
    "cik" = list(ciks = ciks[["cik"]][1], forms = test_forms[1],
                 from_date = test_dates[1], to_date = test_dates[2]),
    "events" = list(ciks = ciks, forms = test_forms_events,
                    from_date = test_dates[1], to_date = test_dates[2]),
    "tenures" = list(ciks = tenures_na, forms = NULL,
                     from_date = NULL, to_date = NULL)
  )

  submissions_ls <- list()

  for (name in names(test_submissions)) {

    args <- test_submissions[[name]]
    forms <- args[["forms"]]

    submissions_ls[[name]] <- data.frame()

    response <- tryCatch({

      submissions_ls[[name]] <- get_submissions(args[["ciks"]], forms = forms,
                                                from_date = args[["from_date"]], to_date = args[["to_date"]],
                                                user_agent = test_user_agent)

      # the forms filter returns only the requested form types
      if ((length(submissions_ls[[name]]) > 0) &&
          (is.null(forms) || all(toupper(submissions_ls[[name]][["form"]]) %in% forms))) {
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
        value = name
      )))

    }

  }

  submissions <- submissions_ls[["ciks"]]
  submissions_tenures <- submissions_ls[["tenures"]]

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

test_that("valid 'dfs'", {

  result_ls <- list()
  errors_ls <- list()

  for (name in names(test_aligns)) {

    args <- test_aligns[[name]]
    dfs <- args[["dfs"]]
    expected <- args[["expected"]]

    response <- tryCatch({

      result <- process_align(dfs)

      if (identical(result, expected)) {
        "success"
      } else {
        NULL
      }

    }, error = function(e) {
      NULL
    })

    if (is.null(response)) {

      errors_ls <- append(errors_ls, list(data.frame(
        call = "process_align",
        value = name
      )))

    }

  }

  if (length(errors_ls) > 0) {

    result <- do.call(rbind, errors_ls)
    result_ls <- append(result_ls, list(result))

  }

  expect_equal(result_ls, list())

})
