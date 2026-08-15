# import pytest
import tempfile
import time
import pandas as pd
import secfile as sec

# @pytest.mark.skip(reason = "long-running test")

test_year = 2006 # both "8-A12B" and "25" are filed electronically (2005 onward)
test_tickers = ["AAPL", ["AAPL", "MSFT"], ["AAPL", "MSFT", "AMZN"]]
test_forms = ["10-K", "10-Q"]
test_dates = ["2023-01-01", "2023-12-31"]
test_dimensions = [None, "typed", "explicit", "StatementEquityComponentsAxis"]
test_user_agent = "username@domain.com"

def test_that(): # valid 'forms', 'tickers', 'ciks', and 'dimension'

  count = 0
  result_ls = []
  errors_ls = []

  try:
    index = sec.get_index(from_year = test_year, to_year = test_year, forms = None,
                          user_agent = test_user_agent)
  except:
    index = pd.DataFrame()

  if (len(index) == 0):

    errors_ls.append({
      "call": "get_index",
      "value": "forms"
    })

  else:

    # amendments are filed with an "/A" suffix (e.g., "10-K/A")
    forms_live = index["form"].str.upper().str.replace(r"/A$", "", regex = True)
    forms_data = sec.data_forms["form"].str.upper()

    forms_na = set(forms_live) - set(forms_data)

    for form in sorted(forms_na):

      errors_ls.append({
        "call": "get_index",
        "value": form
      })

  # the first year is the smallest index
  try:

    index_form = sec.get_index(from_year = 1993, to_year = 1993, forms = test_forms[0],
                               user_agent = test_user_agent)
    response = "success" if (len(index_form) > 0) else None

  except:
    response = None

  if response is None:

    errors_ls.append({
      "call": "get_index",
      "value": test_forms[0]
    })

  try:

    tenures = sec.create_tenures(index, "8-A12B", "25")
    response = "success" if (len(tenures) > 0) else None

  except:

    tenures = pd.DataFrame()
    response = None

  if response is None:

    errors_ls.append({
      "call": "create_tenures",
      "value": "entry_form, exit_form"
    })

  # registrations are filed under section 12(b) ("8-A12B") or 12(g) ("8-A12G");
  # removals are filed by the issuer ("25") or the exchange ("25-NSE")
  try:

    tenures_vector = sec.create_tenures(index, ["8-A12B", "8-A12G"],
                                        ["25", "25-NSE"])
    response = "success" if (len(tenures_vector) >= len(tenures)) else None

  except:
    response = None

  if response is None:

    errors_ls.append({
      "call": "create_tenures",
      "value": "entry_forms, exit_forms"
    })

  for tickers in test_tickers:

    try:

      ciks = sec.get_ciks(tickers, user_agent = test_user_agent)
      response = "success" if (len(ciks) > 0) else None

    except:
      response = None

    if response is None:

      errors_ls.append({
        "call": "get_ciks",
        "value": tickers if isinstance(tickers, str) else ", ".join(tickers)
      })

    count += 1

    if (count % 5 == 0):

      print("pause one second after five requests")
      time.sleep(1)

  try:

    submissions = sec.get_submissions(ciks, forms = test_forms,
                                      from_date = test_dates[0], to_date = test_dates[1],
                                      user_agent = test_user_agent)
    response = "success" if (len(submissions) > 0) else None

  except:

    submissions = pd.DataFrame()
    response = None

  if response is None:

    errors_ls.append({
      "call": "get_submissions",
      "value": "ciks"
    })

  try:

    cik = ciks["cik"].iloc[0]

    submissions_cik = sec.get_submissions(cik, forms = test_forms[0],
                                          from_date = test_dates[0], to_date = test_dates[1],
                                          user_agent = test_user_agent)
    response = "success" if (len(submissions_cik) > 0) else None

  except:
    response = None

  if response is None:

    errors_ls.append({
      "call": "get_submissions",
      "value": "cik"
    })

  # tenures with a missing start date (no lower bound), a missing end date
  # (no upper bound), and closed (both dates)
  try:

    tenures_na = pd.concat([
      tenures[tenures["start_date"].isna()].head(1),
      tenures[tenures["end_date"].isna()].head(1),
      tenures.dropna(subset = ["start_date", "end_date"]).head(1)
    ], ignore_index = True)

    submissions_tenures = sec.get_submissions(tenures_na, forms = None,
                                              user_agent = test_user_agent)
    response = "success" if (len(submissions_tenures) > 0) else None

  except:

    submissions_tenures = pd.DataFrame()
    response = None

  if response is None:

    errors_ls.append({
      "call": "get_submissions",
      "value": "tenures"
    })

  if (len(submissions_tenures) > 0):

    items_live = submissions_tenures["items"].fillna("").str.split(",").explode().str.strip()
    items_live = items_live[items_live != ""]
    items_data = sec.data_items["item"]

    items_na = set(items_live) - set(items_data)

    for item in sorted(items_na):

      errors_ls.append({
        "call": "get_submissions",
        "value": item
      })

  if (len(submissions) > 0):
    submissions_xbrl = submissions[submissions["form"].str.upper() == test_forms[0]]
  else:
    submissions_xbrl = pd.DataFrame()

  with tempfile.TemporaryDirectory() as cache_dir:

    # reuse the cached documents after the first pass
    for dimension in test_dimensions:

      try:

        data = sec.get_data(submissions_xbrl, dimension = dimension, cache_dir = cache_dir,
                            user_agent = test_user_agent)
        response = "success"

        # a specific axis may be absent from the filing
        if (dimension is None) and (len(data) == 0):
          response = None

      except:
        response = None

      if response is None:

        errors_ls.append({
          "call": "get_data",
          "value": dimension
        })

    try:

      date = str(pd.to_datetime(submissions_xbrl["reportDate"].iloc[0]).date())

      data = sec.get_data(submissions_xbrl, date = date, cache_dir = cache_dir,
                          user_agent = test_user_agent)
      response = "success" if (len(data) > 0) else None

    except:
      response = None

    if response is None:

      errors_ls.append({
        "call": "get_data",
        "value": "date"
      })

  if (len(errors_ls) > 0):
    result_ls.extend(errors_ls)

  result_df = pd.DataFrame(result_ls)

  pd.testing.assert_frame_equal(result_df, pd.DataFrame())
