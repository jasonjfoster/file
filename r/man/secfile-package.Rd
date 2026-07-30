\name{secfile-package}
\alias{secfile-package}
\alias{secfile}
\docType{package}
\title{
  \packageTitle{secfile}
}
\description{
  \packageDescription{secfile}
}
\details{

  \code{secfile} is a package that provides simple and efficient access to the SEC's EDGAR functionality for querying and retrieving filings.

  The core functionality of the \code{secfile} package abstracts the complexities of interacting with SEC EDGAR APIs, such as session management, user agent declaration, rate limiting, index parsing, pagination of filing metadata, URL construction, document caching, and inline XBRL parsing. This abstraction allows users to focus on retrieving data rather than managing API details. Use cases include retrieving filings across a range of workflows:

  \itemize{
    \item \strong{Indexes}: master index of all filings by form type and date for universe construction
    \item \strong{Tenures}: status windows built by pairing entry and exit form filings
    \item \strong{Submissions}: filing metadata for any filer with form type and date range filters
    \item \strong{Facts}: investment-level or company-level facts extracted from inline XBRL filings
  }

  The implementation leverages standard HTTP libraries to handle API interactions efficiently and provides support for both R and Python to ensure accessibility for a broad audience.
}
\author{
  \packageAuthor{secfile}
}
