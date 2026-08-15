import gzip
import os
import time
import requests
import pandas as pd
import importlib.resources as pkg_resources
import warnings
from lxml import etree

# the sec returns 403 for user agents that contain a url or impersonate
# a browser and requests contact information (e.g., "username@domain.com")
user_agent = None

class ClassProperty:

  def __init__(self, getter):
    self.getter = getter

  def __get__(self, instance, owner):
    return self.getter(owner)

class Data:

  _forms = None
  _items = None

  @ClassProperty
  def forms(cls):
    """
    Forms Data for the SEC EDGAR APIs

    A data frame with the available forms data for the SEC EDGAR APIs
    sourced from <https://www.sec.gov/Archives/edgar/lookup-data.js>.
    Amendments are filed with an "/A" suffix (e.g., "10-K/A").

    Returns:
      A data frame.
    """

    if cls._forms is None:
      data_path = pkg_resources.files("secfile") / "data" / "forms.csv"
      cls._forms = pd.read_csv(data_path)

    return cls._forms

  @ClassProperty
  def items(cls):
    """
    Items Data for the SEC EDGAR APIs

    A data frame with the available items data for the SEC EDGAR APIs
    sourced from <https://www.sec.gov/Archives/edgar/lookup-data.js>
    and supplemented with items adopted after the source was last updated
    (e.g., "1.05").
    Dotted item numbers (e.g., "2.02") apply to current report ("8-K")
    filings after August 2004 and un-dotted item numbers (e.g., "12")
    apply to earlier filings.

    Returns:
      A data frame.
    """

    if cls._items is None:
      data_path = pkg_resources.files("secfile") / "data" / "items.csv"
      cls._items = pd.read_csv(data_path, dtype = {"item": str})

    return cls._items

class Check:

  @staticmethod
  def user_agent(user_agent):

    valid_user_agent = (isinstance(user_agent, str) and ("@" in user_agent) and
      ("." in user_agent.split("@")[-1]))

    if not valid_user_agent:
      raise ValueError("invalid 'user_agent'")

  @staticmethod
  def forms(forms):

    if isinstance(forms, str):
      forms = [forms]

    valid_forms = (isinstance(forms, (list, tuple)) and (len(forms) > 0) and
      all(isinstance(f, str) and (f.strip() != "") for f in forms))

    if not valid_forms:
      raise ValueError("invalid 'forms'")

  @staticmethod
  def tenures(entry_form, exit_form):

    if isinstance(entry_form, str):
      entry_form = [entry_form]

    valid_entry_form = (isinstance(entry_form, (list, tuple)) and (len(entry_form) > 0) and
      all(isinstance(f, str) and (f.strip() != "") for f in entry_form))

    if not valid_entry_form:
      raise ValueError("invalid 'entry_form'")

    if isinstance(exit_form, str):
      exit_form = [exit_form]

    valid_exit_form = (isinstance(exit_form, (list, tuple)) and (len(exit_form) > 0) and
      all(isinstance(f, str) and (f.strip() != "") for f in exit_form))

    if not valid_exit_form:
      raise ValueError("invalid 'exit_form'")

    if any(f.upper() in [e.upper() for e in entry_form] for f in exit_form):
      raise ValueError("values of 'exit_form' must not equal values of 'entry_form'")

  @staticmethod
  def year(year, type):

    valid_year = isinstance(year, int) and not isinstance(year, bool)

    if not valid_year:
      raise ValueError(f"invalid '{type}'")

    if (year < 1993):
      raise ValueError(f"value of '{type}' must be greater than or equal to 1993")

  @staticmethod
  def years(from_year, to_year):

    if (to_year < from_year):
      raise ValueError("value of 'to_year' must be greater than or equal to value of 'from_year'")

  @staticmethod
  def date(date, type):

    try:
      pd.to_datetime(date, format = "%Y-%m-%d")
    except ValueError:
      raise ValueError(f"invalid '{type}'")

  @staticmethod
  def dates(from_date, to_date):

    if (pd.to_datetime(to_date) < pd.to_datetime(from_date)):
      raise ValueError("value of 'to_date' must be greater than or equal to value of 'from_date'")

  @staticmethod
  def tickers(tickers):

    if isinstance(tickers, str):
      tickers = [tickers]

    valid_tickers = (isinstance(tickers, (list, tuple)) and (len(tickers) > 0) and
      all(isinstance(t, str) and (t.strip() != "") for t in tickers))

    if not valid_tickers:
      raise ValueError("invalid 'tickers'")

  @staticmethod
  def ciks(ciks):

    if isinstance(ciks, (str, int)):
      ciks = [ciks]

    valid_ciks = (isinstance(ciks, (list, tuple)) and (len(ciks) > 0) and
      all(isinstance(c, (str, int)) and str(c).strip().isdigit() for c in ciks))

    if not valid_ciks:
      raise ValueError("invalid 'ciks'")

  @staticmethod
  def dimension(dimension):

    valid_dimension = (dimension is None) or (isinstance(dimension, str) and
      (dimension.strip() != ""))

    if not valid_dimension:
      raise ValueError("invalid 'dimension'")

class Process:

  @staticmethod
  def cik(cik):

    result = str(int(cik)).zfill(10)

    return result

  @staticmethod
  def index(text):

    header = "CIK|Company Name|Form Type|Date Filed|Filename"
    prefix = "https://www.sec.gov/Archives/"

    if (header in text):

      start_idx = text.index(header)
      lines = text[start_idx:].splitlines()[2:]

    else:
      lines = text.splitlines()

    result_ls = []

    for line in lines:

      fields = line.split("|")

      if (len(fields) == 5):

        cik, company, form, date, filename = fields

        result_ls.append({
          "company": company,
          "cik": cik,
          "form": form,
          "date": date,
          "link": prefix + filename
        })

    return result_ls

  @staticmethod
  def url(cik, accession, document):

    accession = str(accession).replace("-", "")

    result = f"https://www.sec.gov/Archives/edgar/data/{int(cik)}/{accession}/{document}"

    return result

  @staticmethod
  def text(element):

    result = (element.text.strip() or None) if (element is not None) and element.text else None

    return result

  @staticmethod
  def contexts(root, date = None, dimension = None):

    ns_instance = "{http://www.xbrl.org/2003/instance}"
    ns_xbrldi = "{http://xbrl.org/2006/xbrldi}"

    result_ls = {}

    for ctx in root.iter(f"{ns_instance}context"):

      ctx_id = ctx.get("id") or ""

      inst = ctx.find(f".//{ns_instance}instant")
      end = ctx.find(f".//{ns_instance}endDate")

      if inst is not None:

        period_type = "instant"
        period_start = None
        period_end = Process.text(inst)

      elif end is not None:

        period_type = "duration"
        period_start = Process.text(ctx.find(f".//{ns_instance}startDate"))
        period_end = Process.text(end)

      else:
        period_type = None

      # instant and duration contexts both match on the end date (fiscal period facts reported as of the date)
      valid_period = (period_type is not None) and ((date is None) or (period_end == date))

      if valid_period:

        dims = []

        for member_type in ["typed", "explicit"]:
          for member in ctx.findall(f".//{ns_xbrldi}{member_type}Member"):

            # typed members nest the value in a child element
            value = next(iter(member), None) if member_type == "typed" else member

            dims.append({
              "axis": member.get("dimension") or "",
              "type": member_type,
              "member": Process.text(value) or ""
            })

        # "typed"/"explicit" matches by member type, otherwise by axis name (with or without namespace prefix)
        if dimension is None:
          match = True
        elif (dimension in ["typed", "explicit"]):
          match = any(dim["type"] == dimension for dim in dims)
        else:
          match = any((dim["axis"] == dimension) or
                      (dim["axis"].split(":")[-1] == dimension) for dim in dims)

        if match:

          result_ls[ctx_id] = {
            "period_type": period_type,
            "period_start": period_start,
            "period_end": period_end,
            "axis": ";".join(dim["axis"] for dim in dims),
            "member_type": ";".join(dim["type"] for dim in dims),
            "member": ";".join(dim["member"] for dim in dims)
          }

    return result_ls

  @staticmethod
  def facts(root, contexts):

    # wide table with rows as contexts and columns as facts
    result_ls = {ctx_id: {"context_id": ctx_id, **info} for ctx_id, info in contexts.items()}

    for el in root.iter():

      ctx_id = el.attrib.get("contextRef")

      if (ctx_id in result_ls):

        tag = el.tag.split("}")[-1]
        result_ls[ctx_id][tag] = (el.text or "").strip()
        result_ls[ctx_id][f"{tag}_unit"] = el.attrib.get("unitRef", "")

    result = pd.DataFrame(result_ls.values())

    return result

class Session:

  _cache = {}

  @staticmethod
  def get(user_agent = user_agent):
    """
    Get the Handle for the SEC EDGAR APIs

    A method to get the handle required to interact with the SEC EDGAR APIs.
    The SEC requires a user agent that declares contact information
    (e.g., "username@domain.com") for fair access. Sessions are cached by
    user agent and reused across subsequent calls.

    Parameters:
      user_agent (str): user agent with contact information.

    Returns:
      A dictionary containing the following elements:
        - "handle" (requests.Session): a session handle object for subsequent requests.

    Examples:
      session = sec.get_session("username@domain.com")
    """

    Check.user_agent(user_agent)

    if (user_agent not in Session._cache):

      session = requests.Session()

      headers = {
        "User-Agent": user_agent,
      }

      session.headers.update(headers)

      result = {
        "handle": session
      }

      Session._cache[user_agent] = result

    return Session._cache[user_agent]

class Index:

  @staticmethod
  def get(from_year = 1993, to_year = None, forms = ["10-K", "10-Q"],
          user_agent = user_agent, session = None):
    """
    Get Index from the SEC EDGAR APIs

    A method to get the master index of filings from the SEC EDGAR APIs
    for a range of years with optional form types.

    Parameters:
      from_year (int): start year (e.g., 1993).
      to_year (int): end year.
      forms (str or list of str): form type or list of form types to filter
        (see `data_forms`) or `None` for all form types.
      user_agent (str): user agent with contact information.
      session (dict): session created by the `get_session` method. When a
        session is provided, the `user_agent` argument is ignored.

    Returns:
      A data frame that contains the company, CIK, form, date, and link
      for each filing.

    Examples:
      index = sec.get_index(user_agent = "username@domain.com")
    """

    if to_year is None:
      to_year = pd.Timestamp.now().year

    Check.year(from_year, "from_year")
    Check.year(to_year, "to_year")
    Check.years(from_year, to_year)

    if forms is not None:

      if isinstance(forms, str):
        forms = [forms]

      Check.forms(forms)

      forms = [form.upper() for form in forms]

    if session is None:
      session = Session.get(user_agent)

    handle = session["handle"]

    count = 0
    result_ls = []

    for year in range(from_year, to_year + 1):
      for qtr in range(1, 5):

        api_url = f"https://www.sec.gov/Archives/edgar/full-index/{year}/QTR{qtr}/master.idx"

        try:

          response = handle.get(api_url)
          text = response.text

        except:
          text = ""

        rows = Process.index(text)

        for row in rows:
          if (forms is None) or (row["form"].upper() in forms):
            result_ls.append(row)

        count += 1

        if (count % 5 == 0):

          print("pause one second after five requests")
          time.sleep(1)

    if (len(result_ls) == 0):
      return pd.DataFrame()

    result = pd.DataFrame(result_ls)
    result["date"] = pd.to_datetime(result["date"])

    return result

class Tenures:

  @staticmethod
  def create(data, entry_form, exit_form):
    """
    Create Tenures for the SEC EDGAR APIs

    A method to create status windows ("tenures") by pairing entry and exit
    form filings for each filer (e.g., exchange listing registration and
    removal).

    Parameters:
      data (data frame): data that contains the company, CIK, form, date,
        and link for each filing created using the `get_index` method.
      entry_form (str or list of str): form type or list of form types that
        start a tenure (e.g., "8-A12B").
      exit_form (str or list of str): form type or list of form types that
        end a tenure (e.g., "25" and "25-NSE").

    Returns:
      A data frame that contains the company, CIK, start date, end date,
      start link, and end link for each tenure. The end date is missing
      for active tenures.

    Examples:
      index = sec.get_index(forms = ["8-A12B", "25", "25-NSE"], user_agent = "username@domain.com")
      tenures = sec.create_tenures(index, "8-A12B", ["25", "25-NSE"])
    """

    Check.tenures(entry_form, exit_form)

    if isinstance(entry_form, str):
      entry_form = [entry_form]

    if isinstance(exit_form, str):
      exit_form = [exit_form]

    entry_form = [f.upper() for f in entry_form]
    exit_form = [f.upper() for f in exit_form]

    df = data.copy()
    df["date"] = pd.to_datetime(df["date"])

    result_ls = []

    for cik, group in df.sort_values(["cik", "date"]).groupby("cik"):

      n_rows = group.shape[0]
      start_date = None
      start_link = None

      for i in range(n_rows):

        row = group.iloc[i]
        form = row["form"].upper()

        if (form in entry_form):

          start_date = row["date"]
          start_link = row["link"]

        elif (form in exit_form):

          result_ls.append({
            "company": row["company"],
            "cik": cik,
            "start_date": start_date,
            "end_date": row["date"],
            "start_link": start_link,
            "end_link": row["link"]
          })

          start_date = None
          start_link = None

      if start_date is not None:

        result_ls.append({
          "company": row["company"],
          "cik": cik,
          "start_date": start_date,
          "end_date": pd.NaT,
          "start_link": start_link,
          "end_link": None
        })

    if (len(result_ls) == 0):
      return pd.DataFrame()

    result = pd.DataFrame(result_ls)

    return result

class Ciks:

  @staticmethod
  def get(tickers = None, user_agent = user_agent, session = None):
    """
    Get CIKs from the SEC EDGAR APIs

    A method to get the Central Index Key ("CIK") for one or more tickers
    from the SEC EDGAR APIs sourced from
    <https://www.sec.gov/files/company_tickers.json>. The result can be
    passed to the `get_submissions` method. Filers with multiple share
    classes have one row for each ticker.

    Parameters:
      tickers (str or list of str): ticker or list of tickers to filter
        or `None` for all tickers.
      user_agent (str): user agent with contact information.
      session (dict): session created by the `get_session` method. When a
        session is provided, the `user_agent` argument is ignored.

    Returns:
      A data frame that contains the company, CIK, and ticker for each
      filer.

    Examples:
      ciks = sec.get_ciks(["AAPL", "MSFT"], user_agent = "username@domain.com")
    """

    if tickers is not None:

      if isinstance(tickers, str):
        tickers = [tickers]

      Check.tickers(tickers)

      tickers = [ticker.upper() for ticker in tickers]

    if session is None:
      session = Session.get(user_agent)

    handle = session["handle"]

    api_url = "https://www.sec.gov/files/company_tickers.json"

    try:

      response = handle.get(api_url)
      data = response.json()

    except:
      data = None

    result_ls = []

    if data is not None:

      for value in data.values():

        ticker = str(value.get("ticker", "")).upper()

        if (tickers is None) or (ticker in tickers):

          result_ls.append({
            "company": value.get("title"),
            "cik": str(value.get("cik_str")),
            "ticker": ticker
          })

    if (len(result_ls) == 0):
      return pd.DataFrame()

    result = pd.DataFrame(result_ls)

    return result

class Submissions:

  @staticmethod
  def get(ciks, forms = ["10-K", "10-Q"], from_date = None, to_date = None,
          user_agent = user_agent, session = None):
    """
    Get Submissions from the SEC EDGAR APIs

    A method to get the filing metadata ("submissions") from the SEC EDGAR
    APIs for filers with optional form types and date range.

    Parameters:
      ciks (str, int, list, or data frame): CIK or list of CIKs, or a data
        frame that contains a `cik` column with optional `start_date` and
        `end_date` columns created using the `get_ciks` or `create_tenures`
        methods.
      forms (str or list of str): form type or list of form types to filter
        (see `data_forms`) or `None` for all form types.
      from_date (str): start date in "YYYY-MM-DD" format.
      to_date (str): end date in "YYYY-MM-DD" format.
      user_agent (str): user agent with contact information.
      session (dict): session created by the `get_session` method. When a
        session is provided, the `user_agent` argument is ignored.

    Returns:
      A data frame that contains the filing metadata for the specified
      filer(s) with the archives URL for each filing.

    Examples:
      ciks = sec.get_ciks("AAPL", user_agent = "username@domain.com")
      submissions = sec.get_submissions(ciks, user_agent = "username@domain.com")
    """

    if forms is not None:

      if isinstance(forms, str):
        forms = [forms]

      Check.forms(forms)

      forms = [form.upper() for form in forms]

    if from_date is not None:
      Check.date(from_date, "from_date")

    if to_date is not None:
      Check.date(to_date, "to_date")

    if (from_date is not None) and (to_date is not None):
      Check.dates(from_date, to_date)

    if isinstance(ciks, pd.DataFrame):

      df = ciks.copy()
      df["cik"] = df["cik"].apply(lambda x: str(int(x)))

      groups = []

      for cik, group in df.groupby("cik"):

        if ("start_date" in group.columns):

          start_dates = pd.to_datetime(group["start_date"])

          # a missing start date means an unknown entry (no lower bound)
          if start_dates.isna().any():
            start_date = pd.to_datetime(from_date)
          else:
            start_date = start_dates.min()

        else:
          start_date = pd.to_datetime(from_date)

        if ("end_date" in group.columns):

          end_dates = pd.to_datetime(group["end_date"])

          # a missing end date means an active tenure (no upper bound)
          if end_dates.isna().any():
            end_date = pd.to_datetime(to_date)
          else:
            end_date = end_dates.max()

        else:
          end_date = pd.to_datetime(to_date)

        groups.append((cik, start_date, end_date))

    else:

      Check.ciks(ciks)

      if isinstance(ciks, (str, int)):
        ciks = [ciks]

      groups = [(str(int(cik)), pd.to_datetime(from_date), pd.to_datetime(to_date))
                for cik in ciks]

    if session is None:
      session = Session.get(user_agent)

    handle = session["handle"]

    count = 0
    result_ls = []

    for cik, start_date, end_date in groups:

      api_url = f"https://data.sec.gov/submissions/CIK{Process.cik(cik)}.json"

      try:

        response = handle.get(api_url)
        data = response.json()

      except:
        data = None

      count += 1

      if (count % 5 == 0):

        print("pause one second after five requests")
        time.sleep(1)

      if data is not None:

        df = pd.DataFrame(data["filings"]["recent"])

        older = []

        for file in data["filings"].get("files", []):

          file_url = f"https://data.sec.gov/submissions/{file['name']}"

          try:

            file_response = handle.get(file_url)
            older.append(pd.DataFrame(file_response.json()))

          except:
            pass

          count += 1

          if (count % 5 == 0):

            print("pause one second after five requests")
            time.sleep(1)

        if (len(older) > 0):
          df = pd.concat([df] + older, ignore_index = True)

        if (len(df) > 0):

          df["filingDate"] = pd.to_datetime(df["filingDate"])

          if forms is not None:
            df = df[df["form"].str.upper().isin(forms)]

          if pd.notna(start_date):
            df = df[df["filingDate"] >= start_date]

          if pd.notna(end_date):
            df = df[df["filingDate"] <= end_date]

          if (len(df) > 0):

            df = df.copy()
            df["url"] = df.apply(lambda x: Process.url(cik, x["accessionNumber"], x["primaryDocument"]),
                                 axis = 1)
            df["cik"] = cik

            result_ls.append(df)

    if (len(result_ls) == 0):
      return pd.DataFrame()

    result = pd.concat(result_ls, ignore_index = True)

    return result

def get(data, dimension = None, date = None, cache_dir = None,
        user_agent = user_agent, session = None):
  """
  Get Data from the SEC EDGAR APIs

  A method to get facts from inline XBRL filings from the SEC EDGAR APIs
  using the specified filing metadata.

  Parameters:
    data (data frame): filing metadata that contains the CIK, accession
      number, primary document, and report date for each filing created
      using the `get_submissions` method.
    dimension (str): dimension of contexts to match (i.e., "typed",
      "explicit", or an axis name such as "InvestmentIdentifierAxis")
      or `None` for all contexts.
    date (str): date in "YYYY-MM-DD" format to match context periods
      or `None` for the report date of each filing. Instant contexts match
      when the instant equals the date and duration contexts match when
      the end date equals the date.
    cache_dir (str): directory to cache downloaded XBRL instance documents
      or `None` to disable caching.
    user_agent (str): user agent with contact information.
    session (dict): session created by the `get_session` method. When a
      session is provided, the `user_agent` argument is ignored.

  Returns:
    A data frame that contains facts from the SEC EDGAR APIs for the
    specified filing metadata with the period type, start and end dates,
    and dimension axes and members for each context.

  Examples:
    ciks = sec.get_ciks("AAPL", user_agent = "username@domain.com")
    submissions = sec.get_submissions(ciks, user_agent = "username@domain.com")
    data = sec.get_data(submissions, user_agent = "username@domain.com")
  """

  Check.dimension(dimension)

  if date is not None:
    Check.date(date, "date")

  df = data.copy()

  if (len(df) == 0):
    return pd.DataFrame()

  if ("isInlineXBRL" in df.columns):
    df = df[df["isInlineXBRL"].astype(bool)]

  df = df.dropna(subset = ["cik", "accessionNumber", "primaryDocument", "reportDate"])
  df = df.reset_index(drop = True)

  if session is None:
    session = Session.get(user_agent)

  handle = session["handle"]

  if cache_dir is not None:
    os.makedirs(cache_dir, exist_ok = True)

  # large filings (e.g., bdc schedules of investments) exceed the default
  # parser's text node limit
  parser = etree.XMLParser(huge_tree = True)

  count = 0
  n_filings = len(df)
  result_ls = []

  for i in range(n_filings):

    row = df.iloc[i]
    cik = str(int(row["cik"]))
    accession = str(row["accessionNumber"]).replace("-", "")
    report_date = row["reportDate"]

    # the inline xbrl instance document is the primary document with
    # the extension replaced (e.g., "form10-k.htm" -> "form10-k_htm.xml")
    name, ext = os.path.splitext(row["primaryDocument"])
    xml_document = f"{name}{ext.replace('.', '_')}.xml"
    xml_url = Process.url(cik, accession, xml_document)

    xml_path = None
    content = None
    from_cache = False

    if cache_dir is not None:
      xml_path = os.path.join(cache_dir, f"{cik}_{accession}.xml.gz")

    if (xml_path is not None) and os.path.exists(xml_path):

      with gzip.open(xml_path, "rb") as file:
        content = file.read()

      from_cache = True

    if (content is None) or (len(content) == 0):

      try:

        response = handle.get(xml_url)
        content = response.content if (response.status_code == 200) else b""

      except:
        content = b""

      from_cache = False

      count += 1

      if (count % 5 == 0):

        print("pause one second after five requests")
        time.sleep(1)

      if (xml_path is not None) and (len(content) > 0):
        with gzip.open(xml_path, "wb") as file:
          file.write(content)

    if (len(content) == 0):
      warnings.warn(f"no content for CIK {cik} accession {accession}", UserWarning)
    else:

      try:
        root = etree.fromstring(content, parser)
      except etree.XMLSyntaxError:
        root = None

      if (root is None) and from_cache:

        # re-download a malformed cached document once
        if os.path.exists(xml_path):
          os.remove(xml_path)

        try:

          response = handle.get(xml_url)
          content = response.content if (response.status_code == 200) else b""

        except:
          content = b""

        count += 1

        if (count % 5 == 0):

          print("pause one second after five requests")
          time.sleep(1)

        if (len(content) > 0):

          with gzip.open(xml_path, "wb") as file:
            file.write(content)

          try:
            root = etree.fromstring(content, parser)
          except etree.XMLSyntaxError:
            root = None

      if root is None:
        warnings.warn(f"malformed XML for CIK {cik} accession {accession}", UserWarning)
      else:

        if date is None:
          target_date = str(pd.to_datetime(report_date).date())
        else:
          target_date = str(pd.to_datetime(date).date())

        contexts = Process.contexts(root, target_date, dimension)
        result_df = Process.facts(root, contexts)

        if (len(result_df) > 0):

          result_df.insert(0, "cik", cik)
          result_df.insert(1, "accession", accession)
          result_df.insert(2, "report_date", str(report_date))

          result_ls.append(result_df)

  if (len(result_ls) == 0):
    return pd.DataFrame()

  result = pd.concat(result_ls, ignore_index = True)

  return result

Data.get = get
