"""paperless-enrich — derive correspondent, title and Betrag from document text.

Finds the first extractor-table entry whose ``match`` regex hits a document's
content and derives the merchant (as correspondent), a readable title and the
``Betrag`` custom field from it. Runs as PAPERLESS_POST_CONSUME_SCRIPT for new
documents and hourly as a backfill safety net.

Design: docs/superpowers/specs/2026-11-23-paperless-paypal-enrichment-design.md

The extractor table is read from ``/var/lib/paperless/extractors.json`` when it
exists (so a new sender is a file edit, not a rebuild), otherwise from the
Nix store default shipped next to this file. To override::

    sudo install -o paperless -m 0644 my-extractors.json \
        /var/lib/paperless/extractors.json

No third-party imports: stdlib only, matching paperless's own runtime.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from decimal import Decimal, InvalidOperation

DEFAULT_TABLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "extractors.json")
OVERRIDE_TABLE = "/var/lib/paperless/extractors.json"
BETRAG_FIELD = "Betrag"
TITLE_MAX = 128


# --- pure logic (exercised by --self-test) --------------------------------


def load_table(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as fh:
        table = json.load(fh)
    if not isinstance(table, list):
        raise ValueError(f"{path}: expected a JSON array of extractor entries")
    return table


def select_extractor(table: list[dict], content: str) -> dict | None:
    """First entry whose `match` regex hits the content, else None."""
    for entry in table:
        pattern = entry.get("match")
        if not pattern:
            continue
        if re.search(pattern, content, re.IGNORECASE | re.DOTALL):
            return entry
    return None


def _search(pattern: str | None, text: str, *, dotall: bool = False) -> str | None:
    """One capture group, case-insensitive. `dotall` lets a pattern cross lines."""
    if not pattern:
        return None
    flags = re.IGNORECASE | (re.DOTALL if dotall else 0)
    found = re.search(pattern, text, flags)
    if not found or not found.groups():
        return None
    return found.group(1)


def clean_name(raw: str) -> str | None:
    """Tidy an extracted payee: collapse whitespace, drop trailing punctuation.

    A private payee's PayPal display name is often their address; use the local
    part so the correspondent list does not fill up with email addresses.
    """
    name = re.sub(r"\s+", " ", raw).strip(" \t.,;:-")
    name = re.sub(r"@.*$", "", name).strip(" \t.,;:-")
    return name[:TITLE_MAX] or None


def normalise_amount(raw: str | None) -> str | None:
    """'1.299,00' -> 'EUR1299.00', '12,99' -> 'EUR12.99', '109.99' -> 'EUR109.99'."""
    if not raw:
        return None
    text = raw.strip()
    if "," in text and "." in text:
        text = text.replace(".", "").replace(",", ".")
    elif "," in text:
        text = text.replace(",", ".")
    try:
        return f"EUR{Decimal(text).quantize(Decimal('0.01'))}"
    except (InvalidOperation, ValueError):
        return None


def extract(entry: dict, content: str) -> tuple[str | None, str | None]:
    """Return (merchant name or None when pinned/absent, normalised amount).

    ``correspondent_regex`` runs against the mail *body* only: mail content
    starts with a ``Subject:/From:/To:`` header block, and a subject like
    "Beleg für Ihre Zahlung an Blue Tomato GmbH" would otherwise swallow the
    following "From:" line. ``correspondent_fallback_regex`` deliberately runs
    against the full content so it *can* use the subject.
    """
    merchant = None
    if entry.get("correspondent") is None:
        body = content.split("\n\n", 1)[-1]
        merchant = clean_name(
            _search(entry.get("correspondent_regex"), body, dotall=True)
            or _search(entry.get("correspondent_fallback_regex"), content)
            or "",
        )
    amount = normalise_amount(
        _search(entry.get("amount_regex"), content)
        or _search(entry.get("amount_fallback_regex"), content),
    )
    return merchant, amount


def build_title(entry: dict, merchant: str | None, amount: str | None, created: str) -> str | None:
    template = entry.get("title")
    if not template:
        return None
    rendered = (
        template.replace("{correspondent}", merchant or entry.get("correspondent") or "")
        .replace("{amount}", amount or "")
        .replace("{created}", created)
    )
    return re.sub(r"\s{2,}", " ", rendered).strip()[:TITLE_MAX] or None


# --- API -----------------------------------------------------------------


class Api:
    def __init__(self, base_url: str, token: str, dry_run: bool, attempts: int = 2):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.dry_run = dry_run
        self.attempts = attempts
        self._cache: dict[str, dict] = {}

    def _request(self, method: str, path: str, body=None, params=None):
        url = self.base_url + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Authorization": f"Token {self.token}",
                "Content-Type": "application/json",
            },
        )
        last: Exception | None = None
        for attempt in range(self.attempts):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    raw = response.read()
                    return json.loads(raw) if raw else None
            except urllib.error.HTTPError as exc:
                # 4xx are answers, not transient failures
                if exc.code < 500:
                    raise
                last = exc
            except (urllib.error.URLError, TimeoutError) as exc:
                last = exc
            if attempt + 1 < self.attempts:
                time.sleep(2**attempt)
        raise RuntimeError(f"{method} {path} failed: {last}")

    def documents(self, page_size: int = 100):
        page = 1
        while True:
            payload = self._request(
                "GET",
                "/api/documents/",
                params={"page": page, "page_size": page_size},
            )
            yield from payload["results"]
            if not payload.get("next"):
                return
            page += 1

    def document(self, doc_id: int) -> dict:
        return self._request("GET", f"/api/documents/{doc_id}/")

    def _lookup(self, resource: str, name: str) -> int | None:
        payload = self._request("GET", f"/api/{resource}/", params={"name__iexact": name})
        results = payload.get("results") or []
        return results[0]["id"] if results else None

    def _ensure(self, resource: str, name: str) -> int | None:
        cached = self._cache.get(f"{resource}:{name.lower()}")
        if cached is not None:
            return cached["id"]
        found = self._lookup(resource, name)
        if found is None:
            if self.dry_run:
                marker = f"new:{name}"
                self._cache[f"{resource}:{name.lower()}"] = {"id": marker}
                return marker
            try:
                created = self._request("POST", f"/api/{resource}/", body={"name": name})
                found = created["id"]
            except urllib.error.HTTPError as exc:
                if exc.code != 400:
                    raise
                # most likely already exists (race / stale cache): look again
                found = self._lookup(resource, name)
                if found is None:
                    raise
        if found is not None:
            self._cache[f"{resource}:{name.lower()}"] = {"id": found}
        return found

    def correspondent_id(self, name: str) -> int | None:
        return self._ensure("correspondents", name)

    def tag_id(self, name: str) -> int | None:
        return self._ensure("tags", name)

    def custom_field_id(self, name: str) -> int | None:
        if "custom_field:" + name not in self._cache:
            payload = self._request("GET", "/api/custom_fields/", params={"page_size": 200})
            for field in payload.get("results") or []:
                if field["name"] == name:
                    self._cache["custom_field:" + name] = {"id": field["id"]}
                    break
            else:
                self._cache["custom_field:" + name] = {"id": None}
        return self._cache["custom_field:" + name]["id"]

    def patch(self, doc_id: int, body: dict) -> None:
        if self.dry_run:
            print(f"  PATCH /api/documents/{doc_id}/ {json.dumps(body, ensure_ascii=False)}")
            return
        self._request("PATCH", f"/api/documents/{doc_id}/", body=body)


def wait_for_api(api: Api, timeout: float) -> None:
    """Block until the API answers: `after=paperless-web` is start, not ready.

    granian binds the port a second or two before its worker can serve, so the
    first backfill after a rebuild would otherwise die on ECONNREFUSED.
    """
    deadline = time.monotonic() + timeout
    while True:
        try:
            api._request("GET", "/api/status/")  # /api/ itself is an HTML index
            return
        except Exception:
            if time.monotonic() >= deadline:
                raise
            time.sleep(5)


# --- one document --------------------------------------------------------


def plan(api: Api, doc: dict, entry: dict) -> dict:
    """Build the minimal PATCH body for one document (may be empty)."""
    content = doc.get("content") or ""
    merchant, amount = extract(entry, content)

    patch: dict = {}

    wanted_name = merchant or entry.get("correspondent")
    if wanted_name:
        current = doc.get("correspondent")
        current_id = current if isinstance(current, int) else (current or {}).get("id")
        wanted_id = api.correspondent_id(clean_name(wanted_name) or wanted_name)
        if wanted_id is not None and wanted_id != current_id:
            patch["correspondent"] = wanted_id

    tag_name = entry.get("tag")
    if tag_name:
        tag_id = api.tag_id(tag_name)
        current_tags = set(doc.get("tags") or [])
        if tag_id is not None and tag_id not in current_tags:
            patch["tags"] = sorted(current_tags) + [tag_id]

    if amount:
        field_id = api.custom_field_id(BETRAG_FIELD)
        if field_id is not None:
            fields = list(doc.get("custom_fields") or [])
            updated, found = [], False
            for item in fields:
                if item.get("field") == field_id:
                    found = True
                    if item.get("value") != amount:
                        updated.append({**item, "value": amount})
                    else:
                        updated.append(item)
                else:
                    updated.append(item)
            if not found:
                updated.append({"field": field_id, "value": amount})
            if updated != fields:
                patch["custom_fields"] = updated

    created = str(doc.get("created") or "")[:10]
    title = build_title(entry, merchant, amount, created)
    if title and title != doc.get("title"):
        patch["title"] = title

    return patch


def enrich(api: Api, doc: dict, table: list[dict]) -> bool:
    content = doc.get("content") or ""
    entry = select_extractor(table, content)
    if entry is None:
        return False
    patch = plan(api, doc, entry)
    if not patch:
        return False
    api.patch(doc["id"], patch)
    return True


# --- self-test -----------------------------------------------------------

# Trimmed copies of real document content (2.20.15, mail fetch). Note the two
# PayPal layouts: the body of the "generic subject" mail carries the payee
# followed by its contact address, while the "truncated subject" mail repeats
# the (PayPal-truncated) subject line inside the body and terminates the payee
# with an ellipsis. Bodies are single long lines, hence [^\n] bounds.

PAYPAL_BODY = (
    "Subject: Beleg f\u00fcr Ihre PayPal-Zahlung\n\n"
    "From: service@paypal.de <service@paypal.de>\n\n"
    "To: Marvin Preu\u00df <xsteadfastx@gmail.com>\n\n"
    "HTML content: Beleg f\u00fcr Ihre PayPal-Zahlung Marvin Preu\u00df, danke, "
    "dass Sie mit PayPal zahlen. Zahlung von Marvin Preu\u00df xsteadfastx@gmail.com "
    "Zahlung an Tiger Media Deutschland GmbH support@tiger.media Mitteilung an "
    "Zahlungsempf\u00e4nger Summe 12,99 \u20ac EUR "
    "Gesamtbetrag dieser Transaktion: 12,99 \u20ac EUR\n"
)

PAYPAL_TRUNCATED = (
    "Subject: Beleg f\u00fcr Ihre Zahlung an Google Payment Irela...\n\n"
    "From: PayPal <service@paypal.de>\n\n"
    "To: Marvin Preu\u00df <xsteadfastx@gmail.com>\n\n"
    "HTML content: Beleg f\u00fcr Ihre Zahlung an Google Payment Irela... Marvin "
    "Preu\u00df, Sie haben eine Zahlung gesendet. Hallo Marvin Preu\u00df! Sie haben "
    "12,99 \u20ac EUR an Google Payment Irela... gezahlt H\u00e4ndler Google Payment "
    "Irela... noreply+support@goog... YouTube Premium Menge: 1 12,99 \u20ac "
    "Zwischensumme 12,99 \u20ac Gesamtbetrag 12,99 \u20ac EUR\n"
)

PAYPAL_NO_CONTACT = (
    "Subject: Beleg f\u00fcr Ihre PayPal-Zahlung\n\n"
    "From: service@paypal.de <service@paypal.de>\n\n"
    "HTML content: Beleg f\u00fcr Ihre PayPal-Zahlung Zahlung von Marvin "
    "Preu\u00df Zahlung an Empire Shop Mitteilung an Zahlungsempf\u00e4nger "
    "Sie haben keine Nachricht eingegeben. Gesamtbetrag dieser Transaktion: "
    "34,99 \u20ac EUR\n"
)

PAYPAL_SUBJECT_ONLY = (
    "Subject: Beleg f\u00fcr Ihre Zahlung an Netflix.com\n\n"
    "From: service@paypal.de <service@paypal.de>\n\n"
    "HTML content: Beleg f\u00fcr Ihre Zahlung an Netflix.com Summe 12,99 \u20ac EUR\n"
)

AMAZON_BODY = (
    "Subject: Bestellt\n\n"
    "From: bestellbestaetigung@amazon.de\n\n"
    "HTML content: Vielen Dank f\u00fcr Ihre Bestellung. Summe 109.99 EUR\n"
)


def self_test() -> int:
    """Run the built-in checks against the *shipped* extractor table."""
    table = load_table(DEFAULT_TABLE)

    def check(content: str) -> tuple[str | None, str | None, str | None]:
        entry = select_extractor(table, content)
        assert entry is not None, "no extractor matched"
        merchant, amount = extract(entry, content)
        return merchant, amount, build_title(entry, merchant, amount, "2026-11-21")

    # generic subject: payee comes from the body, amount from "Gesamtbetrag"
    assert check(PAYPAL_BODY) == (
        "Tiger Media Deutschland GmbH",
        "EUR12.99",
        "Tiger Media Deutschland GmbH EUR12.99 2026-11-21",
    ), check(PAYPAL_BODY)

    # PayPal truncated the payee itself and repeated the subject in the body
    assert check(PAYPAL_TRUNCATED) == (
        "Google Payment Irela",
        "EUR12.99",
        "Google Payment Irela EUR12.99 2026-11-21",
    ), check(PAYPAL_TRUNCATED)

    # no contact address in the body: the subject fallback must carry it
    assert check(PAYPAL_SUBJECT_ONLY) == (
        "Netflix.com",
        "EUR12.99",
        "Netflix.com EUR12.99 2026-11-21",
    ), check(PAYPAL_SUBJECT_ONLY)

    # payee followed by a field label, neither address nor ellipsis nor "gezahlt"
    assert check(PAYPAL_NO_CONTACT) == (
        "Empire Shop",
        "EUR34.99",
        "Empire Shop EUR34.99 2026-11-21",
    ), check(PAYPAL_NO_CONTACT)

    # pinned correspondent: no merchant regex needed
    assert check(AMAZON_BODY) == (
        None,
        "EUR109.99",
        "Amazon EUR109.99 2026-11-21",
    ), check(AMAZON_BODY)

    # a document from a sender we know nothing about must be left alone
    assert select_extractor(table, "Subject: Rechnung\nSumme 5,00 EUR") is None

    # money edge cases
    assert normalise_amount("1.299,00") == "EUR1299.00"
    assert normalise_amount("12,9") == "EUR12.90"
    assert normalise_amount("keine zahl") is None
    assert clean_name("  Foo  GmbH . ") == "Foo GmbH"
    assert clean_name("thomas.walker@gmx.net") == "thomas.walker"
    assert clean_name("...") is None

    print("self-test OK")
    return 0


# --- entry point ---------------------------------------------------------


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--document", type=int, help="enrich one document id")
    target.add_argument("--backfill", action="store_true", help="enrich every document")
    parser.add_argument("--dry-run", action="store_true", help="print the PATCH, write nothing")
    parser.add_argument("--self-test", action="store_true", help="run the built-in checks")
    parser.add_argument("--wait", action="store_true", help="block until the paperless API answers")
    parser.add_argument("--wait-timeout", type=float, default=300, help="seconds to wait for the API")
    parser.add_argument("--extractors", default=os.environ.get("PAPERLESS_EXTRACTORS"))
    parser.add_argument("--token-file", default=os.environ.get("PAPERLESS_TOKEN_FILE"))
    parser.add_argument(
        "--base-url",
        default=os.environ.get("PAPERLESS_BASE_URL", "http://127.0.0.1:28981"),
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    env_document = os.environ.get("DOCUMENT_ID")
    if args.document is None and not args.backfill and env_document:
        args.document = int(env_document)
    if args.document is None and not args.backfill and not args.wait:
        parser.error("need --document, --backfill, --wait or --self-test")

    table_path = args.extractors or (OVERRIDE_TABLE if os.path.exists(OVERRIDE_TABLE) else DEFAULT_TABLE)
    table = load_table(table_path)

    if not args.token_file:
        parser.error("no token file: pass --token-file or set PAPERLESS_TOKEN_FILE")
    with open(args.token_file, encoding="utf-8") as fh:
        token = fh.read().strip()

    api = Api(args.base_url, token, args.dry_run)

    if args.wait:
        wait_for_api(api, args.wait_timeout)
        return 0

    if args.document is not None:
        if enrich(api, api.document(args.document), table):
            print(f"document {args.document}: enriched")
        return 0

    changed = 0
    for doc in api.documents():
        try:
            if enrich(api, doc, table):
                changed += 1
        except Exception as exc:  # one bad document must not stop the sweep
            print(f"document {doc.get('id')}: {exc}", file=sys.stderr)
    print(f"backfill: {changed} document(s) {'would be ' if args.dry_run else ''}updated")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
