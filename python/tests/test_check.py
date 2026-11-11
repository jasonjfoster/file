import re
import pytest
import pandas as pd
import secfile as sec

# test data
test_check_index = pd.DataFrame({
  "company": ["A", "A"],
  "cik": ["1", "1"],
  "form": ["8-A12B", "25"],
  "date": pd.to_datetime(["2006-01-01", "2006-12-31"]),
  "link": ["a", "b"]
})

def test_check(): # input checks

  # test data
  test_check_ciks = "320193"

  # check_user_agent
  with pytest.raises(ValueError, match = re.escape("invalid 'user_agent'")):
    sec.get_session("username")

  # check_year: 'from_year'
  with pytest.raises(ValueError, match = re.escape("invalid 'from_year'")):
    sec.get_index(from_year = "2006")
  with pytest.raises(ValueError, match = re.escape("value of 'from_year' must be greater than or equal to 1993")):
    sec.get_index(from_year = 1992)

  # check_years
  with pytest.raises(ValueError, match = re.escape("value of 'to_year' must be greater than or equal to value of 'from_year'")):
    sec.get_index(from_year = 2006, to_year = 2005)

  # check_forms
  with pytest.raises(ValueError, match = re.escape("invalid 'forms'")):
    sec.get_index(forms = "")

  # check_tenures: 'entry_form'
  with pytest.raises(ValueError, match = re.escape("invalid 'entry_form'")):
    sec.create_tenures(test_check_index, "", "25")

  # check_tenures: 'exit_form'
  with pytest.raises(ValueError, match = re.escape("invalid 'exit_form'")):
    sec.create_tenures(test_check_index, "8-A12B", "")

  # check_tenures: 'exit_form' (equal to 'entry_form')
  with pytest.raises(ValueError, match = re.escape("values of 'exit_form' must not equal values of 'entry_form'")):
    sec.create_tenures(test_check_index, "8-A12B", "8-a12b")

  # check_tickers
  with pytest.raises(ValueError, match = re.escape("invalid 'tickers'")):
    sec.get_ciks("")

  # check_forms
  with pytest.raises(ValueError, match = re.escape("invalid 'forms'")):
    sec.get_submissions(test_check_ciks, forms = [None])

  # check_date: 'from_date'
  with pytest.raises(ValueError, match = re.escape("invalid 'from_date'")):
    sec.get_submissions(test_check_ciks, from_date = "2023-13-01")

  # check_dates
  with pytest.raises(ValueError, match = re.escape("value of 'to_date' must be greater than or equal to value of 'from_date'")):
    sec.get_submissions(test_check_ciks, from_date = "2023-12-31", to_date = "2023-01-01")

  # check_ciks
  with pytest.raises(ValueError, match = re.escape("invalid 'ciks'")):
    sec.get_submissions("abc")

  # check_dimension
  with pytest.raises(ValueError, match = re.escape("invalid 'dimension'")):
    sec.get_data(pd.DataFrame(), dimension = ["a", "b"])
