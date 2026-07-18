# import pytest
import pandas as pd
import secfile as sec

# @pytest.mark.skip(reason = "long-running test")

test_user_agent = "username@domain.com"
test_year = 2024
test_forms = [["8-A12B"], ["8-A12B", "25"]]

def test_that(): # valid 'forms', 'ciks', and 'dimension'

  result_ls = []
  errors_ls = []

  session = sec.get_session(test_user_agent)

  for forms in test_forms:

    try:

      index = sec.get_index(test_year, test_year, forms = forms, session = session)

      if (len(index) > 0):
        response = index
      else:
        response = None

    except:
      response = None

    if response is None:

      errors_ls.append({
        "stage": "index",
        "forms": ", ".join(forms)
      })

  try:

    index = sec.get_index(test_year, test_year, forms = ["8-A12B", "25"],
                          session = session)

    tenures = sec.create_tenures(index, "8-A12B", "25")

    # skip filers without annual or quarterly reports (e.g., foreign issuers)
    submissions = pd.DataFrame()

    for i in range(len(tenures)):

      submissions = sec.get_submissions(tenures.iloc[[i]], forms = ["10-K", "10-Q"],
                                        session = session)

      if (len(submissions) > 0):
        break

    data = sec.get_data(submissions.head(1), dimension = "typed", session = session)

    response = "success"

  except:
    response = None

  if response is None:

    errors_ls.append({
      "stage": "pipeline",
      "forms": "8-A12B, 25"
    })

  if len(errors_ls) > 0:
    result_ls.extend(errors_ls)

  result_df = pd.DataFrame(result_ls)

  pd.testing.assert_frame_equal(result_df, pd.DataFrame())
