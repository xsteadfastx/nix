# Paperless: merchant-as-correspondent enrichment for PayPal documents

Date: 2026-11-23
Status: proposed

## Problem

PayPal documents all land with `correspondent = Paypal` (id 14), because mail
rule **paypal** (id 3) assigns the correspondent from the sender address
(`service@paypal.de`). The shop actually paid — Blue Tomato, Google Payment
Ireland, Netflix — is only in the document text, and paperless's list view
shows `Beleg für Ihre PayPal-Zahlung` 31 times with nothing to tell them apart.

Meanwhile the amount extraction that makes these 128 invoice documents useful
is hardcoded in Nix:

```nix
case "$correspondent_id" in
  1)  # Amazon
  14) # PayPal
esac
```

Adding a third billing sender means editing `hosts/coltrane/paperless.nix`
and running `nixos-rebuild`. That is the part that does not scale — not the
merchant question.

## Evidence (measured on the live instance, 2026-11-23)

- 164 documents; 129 `.eml`, 35 `.pdf`; 0 duplicates by checksum; 0 with empty
  OCR text (OCR/consumption is healthy).
- 0 documents have a `document_type`; none have an ASN; 1 untagged.
- 75 documents, correspondent `Paypal`, all with custom field `Betrag` (id 1)
  filled — the backfill timer works.
- 25 distinct payees across those 75; 18 appear exactly once. Repeats: Google
  Payment Ireland 10, Netflix 6, Bandcamp 3, Abbott 3.
- 44/75 have the payee in the subject (`Beleg für Ihre Zahlung an <payee>`),
  31/75 use the generic subject `Beleg für Ihre PayPal-Zahlung` and carry the
  payee only in the body.
- In every sampled document the body contains
  `Zahlung an <Payee> <contact@email>` followed by
  `Gesamtbetrag dieser Transaktion: 12,99 € EUR` (or `Summe 12,99 € EUR`).
  `Subject: …` is the first line of `content`, so subjects are matchable too.
- Tags `paperless-gpt` / `paperless-gpt-auto` exist with 0 documents —
  leftovers from a dropped LLM-tagging experiment. Out of scope here.

## Decisions

1. **Merchant becomes the correspondent.** One concept per field; the
   correspondent is who billed you. `Paypal` survives as the tag `paypal`
   (payment channel). Private individuals (`simongoetz`, `thomas.walker`) are
   legitimate correspondents — you did pay a person.
2. **Title and `Betrag` are set by the script, not by a workflow.**
   Workflow title templates can only see `correspondent`, dates and filenames
   (verified in `documents/templating/workflows.py`), not `Betrag`; and a
   `Document Updated` workflow would overwrite every manual rename forever.
3. **The extractor table becomes data, not Nix.** A JSON file read at run
   time, so adding a sender is a file edit rather than a rebuild.
4. **The script becomes Python.** The generic table plus create-on-demand plus
   title building is a data-manipulation job; bash + `jq` + `grep -oP` + `curl`
   would be roughly twice the code and untestable. Python 3 is already a
   paperless runtime dependency; stdlib only (`re`, `json`, `urllib`).

## Architecture

Single artifact: `paperless-enrich` (Python, `pkgs.writeScript`), replacing
both `postConsumeScript` and `betragBackfillScript`.

```
                 ┌──────────────────────────────┐
consume ──► PAPERLESS_POST_CONSUME_SCRIPT        │
            └─ paperless-enrich --document N ────┤
                                                 │  GET /api/documents/N/
                     ┌───────────────────────────┘
                     │  pick first extractor whose `match` hits content
                     │  extract payee + amount
                     │  ensure correspondent exists (GET, else POST)
                     ▼
                 PATCH /api/documents/N/
                   { correspondent, title, tags+[paypal], custom_fields[Betrag] }

timer (hourly) ──► paperless-enrich --backfill
                     scans documents that are tagged `paypal`/`amazon` and
                     lack Betrag or have no merchant correspondent, runs the
                     same per-document path
```

Ordering facts this design relies on (verified in the installed 2.20.15
source, `documents/consumer.py`, `documents/signals/handlers.py`):

- `DOCUMENT_ADDED` workflows run at `document_consumption_finished.send()`
  (line 484), i.e. **before** `run_post_consume_script()` (line 594).
- An API `PATCH` sends `document_updated` (`documents/views.py:820`), so
  `DOCUMENT_UPDATED` workflows run **after** the script.
- Workflows are not wired to `post_save`, so no trigger loops. This spec adds
  no workflow at all; it is recorded so nobody later "fixes" ordering wrongly.

## Extractor table

`/var/lib/paperless/extractors.json` (tmpfile, `0775 paperless paperless`,
replaced only if absent — same pattern as the consume dir already in
`paperless.nix`):

```json
[
  {
    "name": "paypal",
    "match": "service@paypal\\.de|PAYPAL \\*",
    "tag": "paypal",
    "correspondent": null,
    "correspondent_regex": "Zahlung an ([^\\n]{2,60}?)(?:\\.\\.\\.|\\s+\\S+@\\S+|\\s+gezahlt)",
    "correspondent_fallback_regex": "Subject: Beleg f(?:ü|u)r Ihre Zahlung an ([^\\n]+)",
    "amount_regex": "Gesamtbetrag(?:\\s+dieser\\s+Transaktion)?:?\\s+([\\d.,]+)\\s*(?:€|EUR)",
    "amount_fallback_regex": "Summe\\s+([\\d.,]+)\\s*(?:€|EUR)",
    "title": "{correspondent} {amount} {created}"
  },
  {
    "name": "amazon",
    "match": "amazon\\.de",
    "tag": null,
    "correspondent": "Amazon",
    "correspondent_regex": null,
    "correspondent_fallback_regex": null,
    "amount_regex": "Summe\\s+([\\d.,]+)\\s*(?:EUR|€)",
    "amount_fallback_regex": null,
    "title": "{correspondent} {amount} {created}"
  }
]
```

Semantics:

- The **first** entry whose `match` matches the document `content` wins; no
  entry matches means the document is left untouched (exit 0).
- `match` may legitimately match on `Subject:` — subjects are part of content.
- `correspondent_regex` runs against the mail **body** (content after the first
  blank line), the fallback against the full content so it can use the subject.
  Captures are line-bounded (`[^\n]`): PayPal repeats the subject inside the
  body, and a cross-line capture swallowed the following sentence —
  see the two layouts below.
- Two PayPal body layouts exist in this archive and both are covered:
  the generic-subject mail names the payee followed by its contact address
  (`Zahlung an Tiger Media Deutschland GmbH support@tiger.media`), the
  truncated-subject mail names it with an ellipsis
  (`an Google Payment Irela... gezahlt`). PayPal truncates the payee itself in
  the second layout — no untruncated spelling exists anywhere in the document.
- An extracted payee that is an email address (private payees) keeps only the
  local part: `thomas.walker@gmx.net` becomes `thomas.walker`.
- `correspondent` non-null pins a fixed correspondent; null means "derive it"
  from `correspondent_regex`, falling back to `correspondent_fallback_regex`.
  Both failing leaves the correspondent untouched and still sets the amount.
- `amount_regex` is tried first, then `amount_fallback_regex`.
- Amounts are normalised to `EUR<digits>.<2 decimals>` (existing format, so
  the saved view and `Betrag` filter keep working). Money rule, exactly:
  if both `.` and `,` occur, drop `.` and turn `,` into `.`; if only `,` occurs,
  turn it into `.`; if only `.` occurs, keep it (Amazon writes `109.99`,
  PayPal writes `12,99` and `1.299,00`). Then `%.2f`.
- `{correspondent}`, `{amount}`, `{created}` in `title`, plus `{original_filename}`
  for scans. Missing values resolve to empty and are collapsed, so no
  `Rechnung  ` double spaces.
- Unmatched placeholder-free titles are allowed; `title` may be omitted to
  leave the title alone.

The file is created with exactly these two entries on first boot. Editing it
later needs no rebuild and no service restart — the script reads it per run.

## Script behaviour

`paperless-enrich` invocations:

- `--document <id>` — the post-consume path. Reads `DOCUMENT_ID` from the
  environment when `--document` is absent, so
  `PAPERLESS_POST_CONSUME_SCRIPT = "${paperless-enrich}"` still works if the
  env var is the only input.
- `--backfill` — iterate documents that have a tag named in any extractor
  entry and are missing either `Betrag` or a merchant correspondent.
- `--dry-run` — print the intended PATCH as JSON, change nothing. Combinable
  with the above.
- `--self-test` — run the extractor core over embedded fixtures and assert.
  Exit non-zero on failure.

Per-document algorithm, idempotent:

1. `GET /api/documents/<id>/`.
2. Pick extractor by `match` on `content`. None → exit 0.
3. Extract amount; extract payee unless `correspondent` is pinned.
4. Trim payee: strip trailing punctuation/whitespace, collapse runs of spaces,
   truncate to 128 characters.
5. Ensure correspondent: `GET /api/correspondents/?name__iexact=<payee>`; on
   empty result `POST /api/correspondents/ {"name": <payee>}`. A 400 naming a
   duplicate counts as success.
6. Build the PATCH body containing only fields whose value actually changes;
   empty body → no request.
7. `PATCH /api/documents/<id>/` with the body.

Never deletes or creates anything except correspondents, and never rewrites a
document whose values already match.

Authentication: the existing `paperless-api-token` sops secret, read from
`config.sops.secrets."paperless-api-token".path` and injected as a path into
the script (never inlined into the Nix store). Base URL
`http://127.0.0.1:28981`.

## Nix changes (`hosts/coltrane/paperless.nix`)

- Delete `extractAmount`, `postConsumeScript`, `betragBackfillScript`; add the
  single `paperless-enrich` derivation and the JSON default file.
- The default table ships in the Nix store, read-only. The script prefers
  `/var/lib/paperless/extractors.json` when it exists and falls back to the
  store copy otherwise. No tmpfiles rule, no clobbering logic: overriding is
  `sudo install -o paperless -m 0644` of an edited copy, documented in the
  header comment of the default table.
- `PAPERLESS_POST_CONSUME_SCRIPT = "${paperless-enrich}"`.
- Timer `paperless-betrag-backfill` → `paperless-enrich.timer`, hourly
  (`OnBootSec=5min`, `OnUnitActiveSec=1h`). It is now a safety net, not the
  primary path.
- `PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{created}_{doc_pk}"`
  plus `PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = "YES"`. Filepath templates have
  no `doc_title` variable (only `title`, `correspondent`, `document_type`,
  `asn`, `owner_username`, `original_name`, `doc_pk`, dates); `doc_pk` is in the
  name because a title+date collision makes the rename fail and would fail
  consumption. Only affects newly consumed files; existing files move only
  under `document_renamer` (see migration).

## Migration of existing documents

Proposal, executed by the user, not by the agent:

```sh
# 1. See what would change for all 75 PayPal documents — no writes.
sudo -u paperless paperless-enrich --backfill --dry-run

# 2. Apply.
sudo -u paperless paperless-enrich --backfill

# 3. Eyeball the result.
curl -s 'http://127.0.0.1:28981/api/documents/?tags__id__all=<paypal-tag-id>&page_size=100&fields=id,title,correspondent' \
  -H "Authorization: Token $TOKEN"
```

Old titles were filenames (`Beleg für Ihre PayPal-Zahlung.eml`), so rewriting
all 75 titles is intended, not a loss. Step 4 is deliberately separate and
optional:

```sh
# 4. Optional: rename files on disk to match PAPERLESS_FILENAME_FORMAT.
sudo -u paperless paperless manage.py document_renamer
```

`document_renamer` moves files; it is a mass mutation and stays out of scope
unless explicitly requested.

## Verification

- `paperless-enrich --self-test` runs the extraction core over four fixtures
  taken from real documents (generic body, PayPal-truncated payee, subject-only
  payee, Amazon) and asserts payee, amount and title. Exposed as
  `checks.<system>.paperless-enrich`, so `nix flake check` exercises it. It
  loads the *shipped* `extractors.json`, not a copy, so table drift fails the
  check.
- `--backfill --dry-run` output is reviewed before any write: 75 documents,
  ~25 distinct correspondents, no payee that looks like an email address or
  the literal string `Zahlungsempfänger`.
- After the real run: `Betrag` still present on 128/128, `paypal` tag on 75,
  correspondent `Paypal` on 0, and one spot-checked document opens with the
  correct merchant, title and amount.

Measured with `--backfill --dry-run` before writing anything: 128 documents
would change (75 PayPal + 53 Amazon) and 46 correspondents would be created.
That is more than the 25 distinct payees, because PayPal's own truncation
splits one shop into two names (`Tiger Media Deutschland GmbH` ×5 and
`Tiger Media Deutschl` ×2). Merging those would need fuzzy matching on
creation; not done — they are two sidebar entries until someone renames one.

## Risks

- **Payee regex overreach.** `Zahlung an (.+?)\s+\S+@\S+` can pick up a
  longer phrase if the body layout differs per mail template. Mitigated by the
  dry run; a bad capture is visible before any write. If a template breaks the
  rule, add a per-template extractor entry rather than complicating the regex.
- **Correspondent proliferation.** ~25 correspondents, 18 used once. Accepted:
  paperless handles hundreds, and the auto-matcher simply will not suggest
  single-document correspondents (it would not have anyway).
- **Title overwrite on re-run.** `--backfill` recomputes titles, so it will
  undo a manual rename of a matched document. Accepted while the safety net is
  short-lived; if that becomes annoying, restrict the title PATCH to documents
  whose title still equals `original_filename` stem.
- **Upgrade drift.** Everything here is verified against paperless-ngx
  **2.20.15** (what the repo pins). Upstream is 3.5.1. Workflow/templating
  internals may change on a bump; the script only uses the public REST API, so
  it survives, but the ordering notes above need re-checking.

## Out of scope

- Document types and storage paths as separate features.
- Any LLM/paperless-gpt tagging. The old `paperless-gpt*` tags stay untouched
  (0 documents).
- Duplicate handling (`PAPERLESS_CONSUMER_DELETE_DUPLICATES`): currently 0
  duplicates, so nothing to fix yet.
- Additional mail rules or IMAP changes.
- Offsite backup of `/var/lib/paperless`: no restic job exists on coltrane and
  164 documents live only on a laptop. Flagged, not solved here.
