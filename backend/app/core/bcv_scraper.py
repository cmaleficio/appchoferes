"""BCV exchange rate scraper.

Translates the bash script logic into Python:
  - Fetches https://www.bcv.org.ve/
  - Extracts USD rate from the #dolar section
  - Extracts the published date
"""

import re
import httpx

BCV_URL = "https://www.bcv.org.ve/"


async def fetch_bcv_rate() -> dict:
    """Scrape BCV website and return {rate, date, source}.

    Returns
        dict with keys:
          - rate (float | None): USD exchange rate in Bs.
          - date (str | None):  date string "YYYY-MM-DD"
          - source (str): always "bcv"
    """
    try:
        async with httpx.AsyncClient(verify=False, timeout=15.0) as client:
            resp = await client.get(BCV_URL)
            resp.raise_for_status()
            html = resp.text
    except Exception as e:
        return {"rate": None, "date": None, "source": "bcv", "error": str(e)}

    # --- Extract rate -------------------------------------------------------
    # BCV format: "60,73920"  (comma = decimal separator, identical to bash tr ',' '.')
    # Some days it may include dots as thousands: "60.739,20"
    rate = None
    m = re.search(r'id="dolar".*?<strong[^>]*class="[^"]*strong-tb[^"]*"[^>]*>([^<]+)</strong>', html, re.DOTALL)
    if m:
        raw = m.group(1).strip()
        raw = raw.replace("\n", "").replace(" ", "")
        # Remove dots (thousands separators), then replace comma with dot (decimal)
        raw = raw.replace(".", "").replace(",", ".")
        try:
            rate = float(raw)
        except ValueError:
            pass

    # --- Extract date -------------------------------------------------------
    date_str = None
    m = re.search(r'class="date-display-single"[^>]*content="([^"]+)"', html)
    if m:
        raw_date = m.group(1)
        date_str = raw_date.split("T")[0]

    return {
        "rate": rate,
        "date": date_str,
        "source": "bcv",
        "error": None if rate else "No se pudo extraer la tasa del BCV",
    }
