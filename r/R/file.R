#' Forms Data for the SEC EDGAR APIs
#'
#' A data frame with the available forms data for the SEC EDGAR APIs
#' sourced from \url{https://www.sec.gov/Archives/edgar/lookup-data.js}.
#' Amendments are filed with an "/A" suffix (e.g., "10-K/A").
#'
#' @format A data frame.
"data_forms"

#' Items Data for the SEC EDGAR APIs
#'
#' A data frame with the available items data for the SEC EDGAR APIs
#' sourced from \url{https://www.sec.gov/Archives/edgar/lookup-data.js}
#' and supplemented with items adopted after the source was last updated
#' (e.g., "1.05").
#' Dotted item numbers (e.g., "2.02") apply to current report ("8-K")
#' filings after August 2004 and un-dotted item numbers (e.g., "12")
#' apply to earlier filings.
#'
#' @format A data frame.
"data_items"

check_user_agent <- function(user_agent) {

  valid_user_agent <- is.character(user_agent) && (length(user_agent) == 1) &&
    grepl("@", user_agent, fixed = TRUE) &&
    grepl(".", sub(".*@", "", user_agent), fixed = TRUE)

  if (!valid_user_agent) {
    stop("invalid 'user_agent'")
  }

}

check_forms <- function(forms) {

  if (is.character(forms)) {
    forms <- trimws(forms)
  }

  valid_forms <- is.character(forms) && (length(forms) > 0) &&
    all(nzchar(forms)) && !anyNA(forms)

  if (!valid_forms) {
    stop("invalid 'forms'")
  }

}

check_tenures <- function(entry_form, exit_form) {

  valid_entry_form <- is.character(entry_form) && (length(entry_form) > 0) &&
    all(nzchar(trimws(entry_form))) && !anyNA(entry_form)

  if (!valid_entry_form) {
    stop("invalid 'entry_form'")
  }

  valid_exit_form <- is.character(exit_form) && (length(exit_form) > 0) &&
    all(nzchar(trimws(exit_form))) && !anyNA(exit_form)

  if (!valid_exit_form) {
    stop("invalid 'exit_form'")
  }

  if (any(toupper(exit_form) %in% toupper(entry_form))) {
    stop("values of 'exit_form' must not equal values of 'entry_form'")
  }

}

check_year <- function(year, type) {

  valid_year <- is.numeric(year) && (length(year) == 1) && (year == round(year))

  if (!valid_year) {
    stop(paste0("invalid '", type, "'"))
  }

  if (year < 1993) {
    stop(paste0("value of '", type, "' must be greater than or equal to 1993"))
  }

}

check_years <- function(from_year, to_year) {

  if (to_year < from_year) {
    stop("value of 'to_year' must be greater than or equal to value of 'from_year'")
  }

}

check_date <- function(date, type) {

  valid_date <- as.Date(date, format = "%Y-%m-%d")

  if (is.na(valid_date)) {
    stop(paste0("invalid '", type, "'"))
  }

}

check_dates <- function(from_date, to_date) {

  if (as.Date(to_date) < as.Date(from_date)) {
    stop("value of 'to_date' must be greater than or equal to value of 'from_date'")
  }

}

check_tickers <- function(tickers) {

  if (is.character(tickers)) {
    tickers <- trimws(tickers)
  }

  valid_tickers <- is.character(tickers) && (length(tickers) > 0) &&
    all(nzchar(tickers)) && !anyNA(tickers)

  if (!valid_tickers) {
    stop("invalid 'tickers'")
  }

}

check_ciks <- function(ciks) {

  if (is.character(ciks)) {
    ciks <- trimws(ciks)
  }

  valid_ciks <- (is.character(ciks) || is.numeric(ciks)) && (length(ciks) > 0) &&
    !anyNA(ciks) && all(grepl("^\\d+$", ciks))

  if (!valid_ciks) {
    stop("invalid 'ciks'")
  }

}

check_dimension <- function(dimension) {

  valid_dimension <- is.null(dimension) || (is.character(dimension) &&
    (length(dimension) == 1) && nzchar(trimws(dimension)))

  if (!valid_dimension) {
    stop("invalid 'dimension'")
  }

}

process_cik <- function(cik) {

  result <- sprintf("%010d", as.integer(cik))

  return(result)

}

process_index <- function(text) {

  header <- "CIK|Company Name|Form Type|Date Filed|Filename"
  prefix <- "https://www.sec.gov/Archives/"

  lines <- strsplit(text, "\r?\n")[[1]]
  start_idx <- which(startsWith(lines, header))

  if (length(start_idx) > 0) {
    lines <- lines[-(1:(start_idx[1] + 1))]
  }

  fields <- strsplit(lines, "|", fixed = TRUE)
  fields <- fields[lengths(fields) == 5]

  if (length(fields) == 0) {
    return(data.frame())
  }

  rows <- do.call(rbind, fields)

  result <- data.frame(
    company = rows[ , 2],
    cik = rows[ , 1],
    form = rows[ , 3],
    date = rows[ , 4],
    link = paste0(prefix, rows[ , 5]),
    stringsAsFactors = FALSE
  )

  return(result)

}

process_url <- function(cik, accession, document) {

  accession <- gsub("-", "", as.character(accession), fixed = TRUE)

  result <- paste0("https://www.sec.gov/Archives/edgar/data/", as.integer(cik), "/",
                   accession, "/", document)

  return(result)

}

process_text <- function(node) {

  result <- xml2::xml_text(node)

  if (is.na(result) || !nzchar(trimws(result))) {
    result <- NA_character_
  } else {
    result <- trimws(result)
  }

  return(result)

}

process_contexts <- function(root, date = NULL, dimension = NULL) {

  ns <- c(
    xbrli = "http://www.xbrl.org/2003/instance",
    xbrldi = "http://xbrl.org/2006/xbrldi"
  )

  result_ls <- list()

  for (ctx in xml2::xml_find_all(root, ".//xbrli:context", ns)) {

    ctx_id <- xml2::xml_attr(ctx, "id")

    if (is.na(ctx_id)) {
      ctx_id <- ""
    }

    inst <- xml2::xml_find_first(ctx, ".//xbrli:instant", ns)
    end <- xml2::xml_find_first(ctx, ".//xbrli:endDate", ns)

    if (!inherits(inst, "xml_missing")) {

      period_type <- "instant"
      period_start <- NA_character_
      period_end <- process_text(inst)

    } else if (!inherits(end, "xml_missing")) {

      period_type <- "duration"
      period_start <- process_text(xml2::xml_find_first(ctx, ".//xbrli:startDate", ns))
      period_end <- process_text(end)

    } else {
      period_type <- NA_character_
    }

    # instant and duration contexts both match on the end date (fiscal period facts reported as of the date)
    valid_period <- !is.na(period_type) && (is.null(date) ||
      (!is.na(period_end) && (period_end == date)))

    if (valid_period) {

      dims <- list()

      for (member_type in c("typed", "explicit")) {
        for (member in xml2::xml_find_all(ctx, paste0(".//xbrldi:", member_type, "Member"), ns)) {

          # typed members nest the value in a child element
          if (member_type == "typed") {
            value <- xml2::xml_find_first(member, "*")
          } else {
            value <- member
          }

          axis <- xml2::xml_attr(member, "dimension")

          if (is.na(axis)) {
            axis <- ""
          }

          member_text <- process_text(value)

          if (is.na(member_text)) {
            member_text <- ""
          }

          dims <- append(dims, list(list(
            axis = axis,
            type = member_type,
            member = member_text
          )))

        }
      }

      # "typed"/"explicit" matches by member type, otherwise by axis name (with or without namespace prefix)
      if (is.null(dimension)) {
        match <- TRUE
      } else if (dimension %in% c("typed", "explicit")) {
        match <- any(vapply(dims, function(dim) dim[["type"]] == dimension, logical(1)))
      } else {
        match <- any(vapply(dims, function(dim) {
          (dim[["axis"]] == dimension) || (sub(".*:", "", dim[["axis"]]) == dimension)
        }, logical(1)))
      }

      if (match) {

        result_ls[[ctx_id]] <- list(
          period_type = period_type,
          period_start = period_start,
          period_end = period_end,
          axis = paste(vapply(dims, function(dim) dim[["axis"]], character(1)), collapse = ";"),
          member_type = paste(vapply(dims, function(dim) dim[["type"]], character(1)), collapse = ";"),
          member = paste(vapply(dims, function(dim) dim[["member"]], character(1)), collapse = ";")
        )

      }

    }

  }

  return(result_ls)

}

process_facts <- function(root, contexts) {

  if (length(contexts) == 0) {
    return(data.frame())
  }

  # wide table with rows as contexts and columns as facts
  result_ls <- list()

  for (ctx_id in names(contexts)) {
    result_ls[[ctx_id]] <- c(list(context_id = ctx_id), contexts[[ctx_id]])
  }

  for (el in xml2::xml_find_all(root, ".//*[@contextRef]")) {

    ctx_id <- xml2::xml_attr(el, "contextRef")

    if (ctx_id %in% names(result_ls)) {

      tag <- xml2::xml_name(el)
      unit <- xml2::xml_attr(el, "unitRef")

      if (is.na(unit)) {
        unit <- ""
      }

      result_ls[[ctx_id]][[tag]] <- trimws(xml2::xml_text(el))
      result_ls[[ctx_id]][[paste0(tag, "_unit")]] <- unit

    }

  }

  cols <- unique(unlist(lapply(result_ls, names)))

  rows_ls <- lapply(result_ls, function(row) {

    cols_na <- setdiff(cols, names(row))

    for (col_na in cols_na) {
      row[[col_na]] <- NA
    }

    data.frame(row[cols], check.names = FALSE, stringsAsFactors = FALSE)

  })

  result <- do.call(rbind, rows_ls)
  rownames(result) <- NULL

  return(result)

}

process_align <- function(dfs) {

  # union of columns in order of appearance with missing values filled
  cols <- unique(unlist(lapply(dfs, colnames)))
  names(cols) <- cols

  result <- data.frame(
    lapply(cols, function(col) {
      do.call(c, lapply(dfs, function(df) {

        if (col %in% colnames(df)) {
          df[[col]]
        } else {
          rep(NA, nrow(df))
        }

      }))
    }),
    check.names = FALSE, stringsAsFactors = FALSE
  )

  rownames(result) <- NULL

  return(result)

}

session_cache <- new.env()

#' Get the Handle for the SEC EDGAR APIs
#'
#' A function to get the handle required to interact with the SEC EDGAR APIs.
#' The SEC requires a user agent that declares contact information
#' (e.g., "username@@domain.com") for fair access. Sessions are cached by
#' user agent and reused across subsequent calls.
#'
#' @param user_agent string. User agent with contact information.
#' @return A list containing the following elements:
#' \item{handle}{A curl handle object for subsequent requests.}
#' @examples
#' session <- get_session("username@@domain.com")
#' @export
get_session <- function(user_agent = NULL) {

  check_user_agent(user_agent)

  if (!exists(user_agent, envir = session_cache)) {

    handle <- curl::new_handle()

    # the sec returns 403 for user agents that contain a url or impersonate
    # a browser and requests contact information (e.g., "username@domain.com")
    headers <- c(
      `User-Agent` = user_agent
    )

    curl::handle_setheaders(handle, .list = headers)

    result <- list(
      handle = handle
    )

    assign(user_agent, result, envir = session_cache)

  }

  return(get(user_agent, envir = session_cache))

}

#' Get Index from the SEC EDGAR APIs
#'
#' A function to get the master index of filings from the SEC EDGAR APIs
#' for a range of years with optional form types.
#'
#' @param from_year integer. Start year (e.g., 1993).
#' @param to_year integer. End year.
#' @param forms string or character vector. Form type or vector of form
#' types to filter (see \code{"data_forms"}) or \code{NULL} for all form types.
#' @param user_agent string. User agent with contact information.
#' @param session list. Session created using the \code{\link{get_session}}
#' function. When a session is provided, the \code{user_agent} argument is ignored.
#' @return A data frame that contains the company, CIK, form, date, and link
#' for each filing.
#'
#' @examples
#' \dontrun{
#' index <- get_index(user_agent = "username@@domain.com")
#' }
#' @export
get_index <- function(from_year = 1993, to_year = NULL, forms = c("10-K", "10-Q"),
                      user_agent = NULL, session = NULL) {

  if (is.null(to_year)) {
    to_year <- as.integer(format(Sys.Date(), "%Y"))
  }

  check_year(from_year, type = "from_year")
  check_year(to_year, type = "to_year")
  check_years(from_year, to_year)

  if (!is.null(forms)) {

    check_forms(forms)

    forms <- toupper(forms)

  }

  if (is.null(session)) {
    session <- get_session(user_agent)
  }

  handle <- session[["handle"]]

  count <- 0
  result_ls <- list()

  for (year in from_year:to_year) {
    for (qtr in 1:4) {

      api_url <- paste0("https://www.sec.gov/Archives/edgar/full-index/", year, "/QTR", qtr, "/master.idx")

      text <- tryCatch({

        response <- curl::curl_fetch_memory(api_url, handle = handle)

        rawToChar(response[["content"]])

      }, error = function(e) {
        return("")
      })

      rows <- process_index(text)

      if (length(rows) > 0) {

        if (!is.null(forms)) {
          rows <- rows[which(toupper(rows[["form"]]) %in% forms), ]
        }

        if (nrow(rows) > 0) {
          result_ls <- append(result_ls, list(rows))
        }

      }

      count <- count + 1

      if (count %% 5 == 0) {

        message("pause one second after five requests")
        Sys.sleep(1)

      }

    }
  }

  if (length(result_ls) == 0) {
    return(data.frame())
  }

  result <- do.call(rbind, result_ls)
  result[["date"]] <- as.Date(result[["date"]])
  rownames(result) <- NULL

  return(result)

}

#' Create Tenures for the SEC EDGAR APIs
#'
#' A function to create status windows ("tenures") by pairing entry and exit
#' form filings for each filer (e.g., exchange listing registration and
#' removal).
#'
#' @param data data frame. Data that contains the company, CIK, form, date,
#' and link for each filing created using the \code{\link{get_index}} function.
#' @param entry_form string or character vector. Form type or vector of
#' form types that start a tenure (e.g., "8-A12B").
#' @param exit_form string or character vector. Form type or vector of
#' form types that end a tenure (e.g., "25" and "25-NSE").
#' @return A data frame that contains the company, CIK, start date, end date,
#' start link, and end link for each tenure. The end date is missing
#' for active tenures.
#'
#' @examples
#' \dontrun{
#' index <- get_index(forms = c("8-A12B", "25", "25-NSE"),
#'                    user_agent = "username@@domain.com")
#'
#' tenures <- create_tenures(index, "8-A12B", c("25", "25-NSE"))
#' }
#' @export
create_tenures <- function(data, entry_form, exit_form) {

  check_tenures(entry_form, exit_form)

  entry_form <- toupper(entry_form)
  exit_form <- toupper(exit_form)

  df <- data
  df[["date"]] <- as.Date(df[["date"]])
  df <- df[order(df[["cik"]], df[["date"]]), ]

  df_ls <- split(df, df[["cik"]])

  result_ls <- list()

  for (cik in names(df_ls)) {

    group <- df_ls[[cik]]

    n_rows <- nrow(group)
    start_date <- as.Date(NA)
    start_link <- NA_character_

    for (i in 1:n_rows) {

      row <- group[i, ]
      form <- toupper(row[["form"]])

      if (form %in% entry_form) {

        start_date <- row[["date"]]
        start_link <- row[["link"]]

      } else if (form %in% exit_form) {

        result_ls <- append(result_ls, list(data.frame(
          company = row[["company"]],
          cik = cik,
          start_date = start_date,
          end_date = row[["date"]],
          start_link = start_link,
          end_link = row[["link"]],
          stringsAsFactors = FALSE
        )))

        start_date <- as.Date(NA)
        start_link <- NA_character_

      }

    }

    if (!is.na(start_date)) {

      result_ls <- append(result_ls, list(data.frame(
        company = row[["company"]],
        cik = cik,
        start_date = start_date,
        end_date = as.Date(NA),
        start_link = start_link,
        end_link = NA_character_,
        stringsAsFactors = FALSE
      )))

    }

  }

  if (length(result_ls) == 0) {
    return(data.frame())
  }

  result <- do.call(rbind, result_ls)
  rownames(result) <- NULL

  return(result)

}

#' Get CIKs from the SEC EDGAR APIs
#'
#' A function to get the Central Index Key ("CIK") for one or more tickers
#' from the SEC EDGAR APIs sourced from
#' \url{https://www.sec.gov/files/company_tickers.json}. The result can be
#' passed to the \code{\link{get_submissions}} function. Filers with multiple
#' share classes have one row for each ticker.
#'
#' @param tickers string or character vector. Ticker or vector of tickers
#' to filter or \code{NULL} for all tickers.
#' @param user_agent string. User agent with contact information.
#' @param session list. Session created using the \code{\link{get_session}}
#' function. When a session is provided, the \code{user_agent} argument is ignored.
#' @return A data frame that contains the company, CIK, and ticker for each
#' filer.
#'
#' @examples
#' \dontrun{
#' ciks <- get_ciks(c("AAPL", "MSFT"), user_agent = "username@@domain.com")
#' }
#' @export
get_ciks <- function(tickers = NULL, user_agent = NULL, session = NULL) {

  if (!is.null(tickers)) {

    check_tickers(tickers)

    tickers <- toupper(tickers)

  }

  if (is.null(session)) {
    session <- get_session(user_agent)
  }

  handle <- session[["handle"]]

  api_url <- "https://www.sec.gov/files/company_tickers.json"

  data <- tryCatch({

    response <- curl::curl(api_url, handle = handle)

    jsonlite::fromJSON(response)

  }, error = function(e) {
    return(NULL)
  })

  result_ls <- list()

  if (!is.null(data)) {

    for (value in data) {

      ticker <- toupper(as.character(value[["ticker"]]))

      if (is.null(tickers) || (ticker %in% tickers)) {

        result_ls <- append(result_ls, list(data.frame(
          company = value[["title"]],
          cik = as.character(value[["cik_str"]]),
          ticker = ticker,
          stringsAsFactors = FALSE
        )))

      }

    }

  }

  if (length(result_ls) == 0) {
    return(data.frame())
  }

  result <- do.call(rbind, result_ls)

  return(result)

}

#' Get Submissions from the SEC EDGAR APIs
#'
#' A function to get the filing metadata ("submissions") from the SEC EDGAR
#' APIs for filers with optional form types and date range.
#'
#' @param ciks string, numeric, vector, or data frame. CIK or vector of CIKs,
#' or a data frame that contains a \code{cik} column with optional
#' \code{start_date} and \code{end_date} columns created using the
#' \code{\link{get_ciks}} or \code{\link{create_tenures}} functions.
#' @param forms string or character vector. Form type or vector of form
#' types to filter (see \code{"data_forms"}) or \code{NULL} for all form types.
#' @param from_date string. Start date in "YYYY-MM-DD" format.
#' @param to_date string. End date in "YYYY-MM-DD" format.
#' @param user_agent string. User agent with contact information.
#' @param session list. Session created using the \code{\link{get_session}}
#' function. When a session is provided, the \code{user_agent} argument is ignored.
#' @return A data frame that contains the filing metadata for the specified
#' filer(s) with the archives URL for each filing.
#'
#' @examples
#' \dontrun{
#' ciks <- get_ciks("AAPL", user_agent = "username@@domain.com")
#'
#' submissions <- get_submissions(ciks, user_agent = "username@@domain.com")
#' }
#' @export
get_submissions <- function(ciks, forms = c("10-K", "10-Q"), from_date = NULL, to_date = NULL,
                            user_agent = NULL, session = NULL) {

  if (!is.null(forms)) {

    check_forms(forms)

    forms <- toupper(forms)

  }

  if (!is.null(from_date)) {
    check_date(from_date, type = "from_date")
  }

  if (!is.null(to_date)) {
    check_date(to_date, type = "to_date")
  }

  if (!is.null(from_date) && !is.null(to_date)) {
    check_dates(from_date, to_date)
  }

  if (is.null(from_date)) {
    from_date <- NA
  }

  if (is.null(to_date)) {
    to_date <- NA
  }

  groups <- list()

  if (is.data.frame(ciks)) {

    df <- ciks
    df[["cik"]] <- as.character(as.integer(df[["cik"]]))

    df_ls <- split(df, df[["cik"]])

    for (cik in names(df_ls)) {

      group <- df_ls[[cik]]

      if ("start_date" %in% colnames(group)) {

        start_dates <- as.Date(group[["start_date"]])

        # a missing start date means an unknown entry (no lower bound)
        if (anyNA(start_dates)) {
          start_date <- as.Date(from_date)
        } else {
          start_date <- min(start_dates)
        }

      } else {
        start_date <- as.Date(from_date)
      }

      if ("end_date" %in% colnames(group)) {

        end_dates <- as.Date(group[["end_date"]])

        # a missing end date means an active tenure (no upper bound)
        if (anyNA(end_dates)) {
          end_date <- as.Date(to_date)
        } else {
          end_date <- max(end_dates)
        }

      } else {
        end_date <- as.Date(to_date)
      }

      groups <- append(groups, list(list(
        cik = cik,
        start_date = start_date,
        end_date = end_date
      )))

    }

  } else {

    check_ciks(ciks)

    for (cik in ciks) {

      groups <- append(groups, list(list(
        cik = as.character(as.integer(cik)),
        start_date = as.Date(from_date),
        end_date = as.Date(to_date)
      )))

    }

  }

  if (is.null(session)) {
    session <- get_session(user_agent)
  }

  handle <- session[["handle"]]

  count <- 0
  result_ls <- list()

  for (group in groups) {

    cik <- group[["cik"]]
    start_date <- group[["start_date"]]
    end_date <- group[["end_date"]]

    api_url <- paste0("https://data.sec.gov/submissions/CIK", process_cik(cik), ".json")

    data <- tryCatch({

      response <- curl::curl(api_url, handle = handle)

      jsonlite::fromJSON(response)

    }, error = function(e) {
      return(NULL)
    })

    count <- count + 1

    if (count %% 5 == 0) {

      message("pause one second after five requests")
      Sys.sleep(1)

    }

    if (!is.null(data)) {

      df <- as.data.frame(data[["filings"]][["recent"]],
                          stringsAsFactors = FALSE)

      older <- list()
      files <- data[["filings"]][["files"]]

      if (length(files) > 0) {

        for (name in files[["name"]]) {

          file_url <- paste0("https://data.sec.gov/submissions/", name)

          file_df <- tryCatch({

            file_response <- curl::curl(file_url, handle = handle)

            as.data.frame(jsonlite::fromJSON(file_response),
                          stringsAsFactors = FALSE)

          }, error = function(e) {
            return(NULL)
          })

          if (!is.null(file_df)) {
            older <- append(older, list(file_df))
          }

          count <- count + 1

          if (count %% 5 == 0) {

            message("pause one second after five requests")
            Sys.sleep(1)

          }

        }

      }

      if (length(older) > 0) {

        dfs <- append(list(df), older)
        df <- process_align(dfs)

      }

      if (nrow(df) > 0) {

        df[["filingDate"]] <- as.Date(df[["filingDate"]])

        if (!is.null(forms)) {
          df <- df[which(toupper(df[["form"]]) %in% forms), ]
        }

        if (!is.na(start_date)) {
          df <- df[which(df[["filingDate"]] >= start_date), ]
        }

        if (!is.na(end_date)) {
          df <- df[which(df[["filingDate"]] <= end_date), ]
        }

        if (nrow(df) > 0) {

          df[["url"]] <- process_url(cik, df[["accessionNumber"]], df[["primaryDocument"]])
          df[["cik"]] <- cik

          result_ls <- append(result_ls, list(df))

        }

      }

    }

  }

  if (length(result_ls) == 0) {
    return(data.frame())
  }

  result <- process_align(result_ls)

  return(result)

}

#' Get Data from the SEC EDGAR APIs
#'
#' A function to get facts from inline XBRL filings from the SEC EDGAR APIs
#' using the specified filing metadata.
#'
#' @param data data frame. Filing metadata that contains the CIK, accession
#' number, primary document, and report date for each filing created
#' using the \code{\link{get_submissions}} function.
#' @param dimension string. Dimension of contexts to match (i.e., "typed",
#' "explicit", or an axis name such as "InvestmentIdentifierAxis")
#' or \code{NULL} for all contexts.
#' @param date string. Date in "YYYY-MM-DD" format to match context periods
#' or \code{NULL} for the report date of each filing. Instant contexts match
#' when the instant equals the date and duration contexts match when
#' the end date equals the date.
#' @param cache_dir string. Directory to cache downloaded XBRL instance documents
#' or \code{NULL} to disable caching.
#' @param user_agent string. User agent with contact information.
#' @param session list. Session created using the \code{\link{get_session}}
#' function. When a session is provided, the \code{user_agent} argument is ignored.
#' @return A data frame that contains facts from the SEC EDGAR APIs for the
#' specified filing metadata with the period type, start and end dates,
#' and dimension axes and members for each context.
#'
#' @examples
#' \dontrun{
#' ciks <- get_ciks("AAPL", user_agent = "username@@domain.com")
#'
#' submissions <- get_submissions(ciks, user_agent = "username@@domain.com")
#'
#' data <- get_data(submissions, user_agent = "username@@domain.com")
#' }
#' @export
get_data <- function(data, dimension = NULL, date = NULL, cache_dir = NULL,
                     user_agent = NULL, session = NULL) {

  check_dimension(dimension)

  if (!is.null(date)) {
    check_date(date, type = "date")
  }

  df <- data

  if (length(df) == 0) {
    return(data.frame())
  }

  if ("isInlineXBRL" %in% colnames(df)) {
    df <- df[which(as.logical(df[["isInlineXBRL"]])), ]
  }

  for (col in c("cik", "accessionNumber", "primaryDocument", "reportDate")) {
    df <- df[which(!is.na(df[[col]])), ]
  }

  if (is.null(session)) {
    session <- get_session(user_agent)
  }

  handle <- session[["handle"]]

  if (!is.null(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # large filings (e.g., bdc schedules of investments) exceed the default
  # parser's text node limit
  parser_options <- "HUGE"

  count <- 0
  n_filings <- nrow(df)
  result_ls <- list()

  for (i in seq_len(n_filings)) {

    row <- df[i, ]
    cik <- as.character(as.integer(row[["cik"]]))
    accession <- gsub("-", "", as.character(row[["accessionNumber"]]), fixed = TRUE)
    report_date <- row[["reportDate"]]

    # the inline xbrl instance document is the primary document with
    # the extension replaced (e.g., "form10-k.htm" -> "form10-k_htm.xml")
    primary_document <- row[["primaryDocument"]]

    if (grepl("\\.[^.]+$", primary_document)) {
      xml_document <- sub("\\.([^.]+)$", "_\\1.xml", primary_document)
    } else {
      xml_document <- paste0(primary_document, ".xml")
    }

    xml_url <- process_url(cik, accession, xml_document)

    xml_path <- NULL
    content <- NULL
    from_cache <- FALSE

    if (!is.null(cache_dir)) {
      xml_path <- file.path(cache_dir, paste0(cik, "_", accession, ".xml.gz"))
    }

    if (!is.null(xml_path) && file.exists(xml_path)) {

      con <- gzfile(xml_path, "rb")

      content <- raw()

      repeat {

        chunk <- readBin(con, "raw", n = 1048576)

        if (length(chunk) == 0) {
          break
        }

        content <- c(content, chunk)

      }

      close(con)

      from_cache <- TRUE

    }

    if (is.null(content) || (length(content) == 0)) {

      content <- tryCatch({

        response <- curl::curl_fetch_memory(xml_url, handle = handle)

        if (response[["status_code"]] == 200) {
          response[["content"]]
        } else {
          raw()
        }

      }, error = function(e) {
        return(raw())
      })

      from_cache <- FALSE

      count <- count + 1

      if (count %% 5 == 0) {

        message("pause one second after five requests")
        Sys.sleep(1)

      }

      if (!is.null(xml_path) && (length(content) > 0)) {

        con <- gzfile(xml_path, "wb")
        writeBin(content, con)
        close(con)

      }

    }

    if (length(content) == 0) {
      warning(paste0("no content for CIK ", cik, " accession ", accession))
    } else {

      root <- tryCatch({
        xml2::read_xml(content, options = parser_options)
      }, error = function(e) {
        return(NULL)
      })

      if (is.null(root) && from_cache) {

        # re-download a malformed cached document once
        if (file.exists(xml_path)) {
          file.remove(xml_path)
        }

        content <- tryCatch({

          response <- curl::curl_fetch_memory(xml_url, handle = handle)

          if (response[["status_code"]] == 200) {
            response[["content"]]
          } else {
            raw()
          }

        }, error = function(e) {
          return(raw())
        })

        count <- count + 1

        if (count %% 5 == 0) {

          message("pause one second after five requests")
          Sys.sleep(1)

        }

        if (length(content) > 0) {

          con <- gzfile(xml_path, "wb")
          writeBin(content, con)
          close(con)

          root <- tryCatch({
            xml2::read_xml(content, options = parser_options)
          }, error = function(e) {
            return(NULL)
          })

        }

      }

      if (is.null(root)) {
        warning(paste0("malformed XML for CIK ", cik, " accession ", accession))
      } else {

        if (is.null(date)) {
          target_date <- as.character(as.Date(report_date))
        } else {
          target_date <- as.character(as.Date(date))
        }

        contexts <- process_contexts(root, target_date, dimension)
        result_df <- process_facts(root, contexts)

        if (length(result_df) > 0) {

          result_df <- cbind(data.frame(
            cik = cik,
            accession = accession,
            report_date = as.character(report_date),
            stringsAsFactors = FALSE
          ), result_df)

          result_ls <- append(result_ls, list(result_df))

        }

      }

    }

  }

  if (length(result_ls) == 0) {
    return(data.frame())
  }

  result <- process_align(result_ls)

  return(result)

}
