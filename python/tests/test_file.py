import tempfile
import time
import pandas as pd
import secfile as sec
from secfile.file import Process

# test arguments
test_year = 2006 # both "8-A12B" and "25" are filed electronically (2005 onward)
test_tickers = ["AAPL", ["AAPL", "MSFT"], ["AAPL", "MSFT", "AMZN"]]
test_forms = ["10-K", "10-Q"]
test_forms_events = "8-K"
test_dates = ["2023-01-01", "2023-12-31"]
test_dimensions = [None, "typed", "explicit", "StatementEquityComponentsAxis"]
test_user_agent = "username@domain.com"

# the first year is the smallest index
test_indexes = {
  "all forms": {"from_year": test_year, "forms": None},
  "first year": {"from_year": 1993, "forms": test_forms[0:1]},
  "tenure forms": {"from_year": test_year, "forms": ["8-A12B", "25", "25-NSE"]}
}

# registrations are filed under section 12(b) ("8-A12B") or 12(g) ("8-A12G");
# removals are filed by the issuer ("25") or the exchange ("25-NSE")
test_tenures = {
  "entry_form, exit_form": {"entry_form": "8-A12B", "exit_form": "25"},
  "entry_form, exit_forms": {"entry_form": "8-A12B", "exit_form": ["25", "25-NSE"]},
  "entry_forms, exit_forms": {"entry_form": ["8-A12B", "8-A12G"], "exit_form": ["25", "25-NSE"]}
}

# test data

# aligned (shared columns) and misaligned (missing columns, mixed
# types, and zero rows) data frames
test_aligns = [
  {
    "value": "columns",
    "dfs": [
      pd.DataFrame({
        "filingDate": pd.to_datetime(["2023-01-01"]),
        "form": ["10-K"]
      }),
      pd.DataFrame({
        "filingDate": pd.to_datetime(["2023-01-02"]),
        "form": ["10-Q"]
      })
    ],
    "expected": pd.DataFrame({
      "filingDate": pd.to_datetime(["2023-01-01", "2023-01-02"]),
      "form": ["10-K", "10-Q"]
    })
  },
  {
    "value": "fill",
    "dfs": [
      pd.DataFrame({
        "filingDate": pd.to_datetime(["2023-01-01", "2023-01-02"]),
        "size": [100, 200],
        "form": ["10-K", "10-Q"]
      }),
      pd.DataFrame({
        "filingDate": pd.to_datetime(["2023-01-03"]),
        "form": ["8-K"],
        "us-gaap:Assets": ["1000"]
      }),
      pd.DataFrame({
        "filingDate": pd.to_datetime([])
      })
    ],
    "expected": pd.DataFrame({
      "filingDate": pd.to_datetime(["2023-01-01", "2023-01-02", "2023-01-03"]),
      "size": [100, 200, None],
      "form": ["10-K", "10-Q", "8-K"],
      "us-gaap:Assets": [None, None, "1000"]
    })
  }
]

def test_that(): # valid 'forms', 'tickers', 'ciks', and 'dimension'

  count = 0
  result_ls = []
  errors_ls = []

  index_ls = {}

  for name, args in test_indexes.items():

    from_year = args["from_year"]
    forms = args["forms"]

    index_ls[name] = pd.DataFrame()

    try:

      index_ls[name] = sec.get_index(from_year = from_year, to_year = from_year, forms = forms,
                                     user_agent = test_user_agent)

      # the forms filter returns only the requested form types
      response = "success" if ((len(index_ls[name]) > 0) and
                               ((forms is None) or index_ls[name]["form"].str.upper().isin(forms).all())) else None

    except:
      response = None

    if response is None:

      errors_ls.append({
        "call": "get_index",
        "value": name
      })

  index = index_ls["all forms"]

  if (len(index) > 0):

    # amendments are filed with an "/A" suffix (e.g., "10-K/A")
    forms_live = index["form"].str.upper().str.replace(r"/A$", "", regex = True)
    forms_data = sec.data_forms["form"].str.upper()

    forms_na = set(forms_live) - set(forms_data)

    for form in sorted(forms_na):

      errors_ls.append({
        "call": "get_index",
        "value": form
      })

  tenures_ls = {}

  for name, args in test_tenures.items():

    entry_form = args["entry_form"]
    exit_form = args["exit_form"]

    tenures_ls[name] = pd.DataFrame()

    try:

      tenures_ls[name] = sec.create_tenures(index, entry_form, exit_form)
      response = "success" if (len(tenures_ls[name]) > 0) else None

    except:
      response = None

    if response is None:

      errors_ls.append({
        "call": "create_tenures",
        "value": name
      })

  tenures = tenures_ls["entry_form, exit_form"]

  # more form types match at least as many tenures and the forms filter agrees
  try:

    tenures_forms = sec.create_tenures(index_ls["tenure forms"], "8-A12B", ["25", "25-NSE"])

    n_rows = [len(tenures) for tenures in tenures_ls.values()]
    response = "success" if ((n_rows == sorted(n_rows)) and
                             (len(tenures_forms) == len(tenures_ls["entry_form, exit_forms"]))) else None

  except:
    response = None

  if response is None:

    errors_ls.append({
      "call": "create_tenures",
      "value": "forms"
    })

  ciks = pd.DataFrame()

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

  # tenures with a missing start date (no lower bound), a missing end date
  # (no upper bound), and closed (both dates)
  try:

    tenures_na = pd.concat([
      tenures[tenures["start_date"].isna()].head(1),
      tenures[tenures["end_date"].isna()].head(1),
      tenures.dropna(subset = ["start_date", "end_date"]).head(1)
    ], ignore_index = True)

  except:
    tenures_na = pd.DataFrame()

  test_submissions = {
    "ciks": {"ciks": ciks, "forms": test_forms,
             "from_date": test_dates[0], "to_date": test_dates[1]},
    "cik": {"ciks": ciks["cik"].iloc[0] if (len(ciks) > 0) else None, "forms": test_forms[0:1],
            "from_date": test_dates[0], "to_date": test_dates[1]},
    "events": {"ciks": ciks, "forms": [test_forms_events],
               "from_date": test_dates[0], "to_date": test_dates[1]},
    "tenures": {"ciks": tenures_na, "forms": None,
                "from_date": None, "to_date": None}
  }

  submissions_ls = {}

  for name, args in test_submissions.items():

    forms = args["forms"]

    submissions_ls[name] = pd.DataFrame()

    try:

      submissions_ls[name] = sec.get_submissions(args["ciks"], forms = forms,
                                                 from_date = args["from_date"], to_date = args["to_date"],
                                                 user_agent = test_user_agent)

      # the forms filter returns only the requested form types
      response = "success" if ((len(submissions_ls[name]) > 0) and
                               ((forms is None) or submissions_ls[name]["form"].str.upper().isin(forms).all())) else None

    except:
      response = None

    if response is None:

      errors_ls.append({
        "call": "get_submissions",
        "value": name
      })

  submissions = submissions_ls["ciks"]
  submissions_tenures = submissions_ls["tenures"]

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

def test_align(): # valid 'dfs'

  result_ls = []
  errors_ls = []

  for align in test_aligns:

    try:

      result = Process.align(align["dfs"])

      pd.testing.assert_frame_equal(result, align["expected"])
      response = "success"

    except:
      response = None

    if response is None:

      errors_ls.append({
        "call": "Process.align",
        "value": align["value"]
      })

  if (len(errors_ls) > 0):
    result_ls.extend(errors_ls)

  result_df = pd.DataFrame(result_ls)

  pd.testing.assert_frame_equal(result_df, pd.DataFrame())
