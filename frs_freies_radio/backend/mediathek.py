from __future__ import annotations

import os
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from typing import Callable, List, Optional, Tuple

import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BASE_URL = "https://www.freies-radio.de"
MEDIATHEK_URL = f"{BASE_URL}/mediathek"
USER_AGENT = "frs-proxy/1.0 (+https://github.com/DonMassa84/frs_freies_radio)"
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "10"))
HEAD_TIMEOUT = float(os.getenv("HEAD_TIMEOUT_SECONDS", "5"))


def _create_session() -> requests.Session:
    session = requests.Session()
    retry = Retry(total=2, backoff_factor=0.3, status_forcelist=[429, 500, 502, 503, 504])
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    session.headers.update({"User-Agent": USER_AGENT})
    return session


def _parse_datetime_value(value: str) -> Tuple[Optional[str], Optional[str]]:
    if not value:
        return None, None
    value = value.strip()
    if "T" in value:
        parts = value.split("T", 1)
        date_part = parts[0][:10]
        time_part = parts[1][:5] if len(parts[1]) >= 5 else None
        return date_part, time_part
    match = re.match(r"(\d{4}-\d{2}-\d{2})", value)
    if match:
        return match.group(1), None
    match = re.match(r"(\d{2}:\d{2})", value)
    if match:
        return None, match.group(1)
    return None, None


def _extract_text(node) -> str:
    if not node:
        return ""
    return " ".join(node.stripped_strings)


def _build_audio_url(date_str: Optional[str], start_time: Optional[str]) -> str:
    if not date_str or not start_time:
        return ""
    yyyymmdd = date_str.replace("-", "")
    hhmm = start_time.replace(":", "")
    # Assumption: file naming pattern is YYYYMMDD-HHMM.mp3
    return f"{BASE_URL}/systemfiles/mediathek/{yyyymmdd}-{hhmm}.mp3"


def _check_audio_available(session: requests.Session, url: str) -> bool:
    if not url:
        return False
    try:
        resp = session.head(url, timeout=HEAD_TIMEOUT)
        return resp.status_code == 200
    except requests.RequestException:
        return False


def parse_mediathek(html: str) -> List[dict]:
    soup = BeautifulSoup(html, "html.parser")
    rows = soup.select(".view-content .views-row")
    if not rows:
        rows = soup.select(".views-row")
    if not rows:
        rows = soup.select("article")

    items: List[dict] = []
    for row in rows:
        time_tags = row.find_all("time")
        date_str = None
        start_time = None
        end_time = None
        if time_tags:
            date_str, start_time = _parse_datetime_value(time_tags[0].get("datetime") or time_tags[0].get_text())
            if len(time_tags) > 1:
                _, end_time = _parse_datetime_value(time_tags[1].get("datetime") or time_tags[1].get_text())

        show_link = row.select_one("a.use-ajax") or row.select_one("h3 a") or row.select_one("a")
        show_name = _extract_text(show_link)

        episode = ""
        episode_el = row.select_one("span.text-base.font-bold") or row.select_one("span.text-base")
        if episode_el:
            episode = _extract_text(episode_el)

        teaser = None
        teaser_el = row.select_one(".field--name-field-teaser") or row.find("p")
        if teaser_el:
            teaser_text = _extract_text(teaser_el)
            teaser = teaser_text if teaser_text else None

        items.append(
            {
                "date": date_str or "",
                "start": start_time or "",
                "end": end_time or "",
                "show": show_name,
                "episode": episode,
                "teaser": teaser,
                "audioUrl": _build_audio_url(date_str, start_time),
            }
        )

    return items


def fetch_mediathek_items(
    html_fetcher: Optional[Callable[[], str]] = None,
    availability_checker: Optional[Callable[[str], bool]] = None,
) -> List[dict]:
    session = _create_session()

    def _default_fetcher() -> str:
        resp = session.get(MEDIATHEK_URL, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        return resp.text

    html_fetch = html_fetcher or _default_fetcher
    items = parse_mediathek(html_fetch())

    def _default_checker(url: str) -> bool:
        return _check_audio_available(session, url)

    checker = availability_checker or _default_checker
    with ThreadPoolExecutor(max_workers=6) as executor:
        future_map = {}
        for item in items:
            audio_url = item.get("audioUrl", "")
            if not audio_url:
                item["audioAvailable"] = False
                continue
            future_map[executor.submit(checker, audio_url)] = item

        for future in as_completed(future_map):
            item = future_map[future]
            try:
                item["audioAvailable"] = bool(future.result())
            except Exception:
                item["audioAvailable"] = False
    return items
