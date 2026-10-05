# Matrix — homeserver and bridges

The Matrix deployment lives entirely on **dipper**. This is the operational
runbook: how the pieces fit, how to add a user, how to connect a bridge, and what
to check when something looks broken.

Config: [`hosts/dipper/matrix/`](../hosts/dipper/matrix/) — `default.nix`
(homeserver, Caddy, tlsrouter, WhatsApp/Signal bridges), `turn.nix` (LiveKit,
lk-jwt, TURN), and the two local bridge modules
[`mautrix-telegram-go.nix`](../hosts/dipper/matrix/mautrix-telegram-go.nix) and
[`mautrix-slack.nix`](../hosts/dipper/matrix/mautrix-slack.nix). Secrets:
[`hosts/dipper/secrets.nix`](../hosts/dipper/secrets.nix).

## Architecture

| Piece | What | Where |
| --- | --- | --- |
| `tuwunel` | Homeserver (conduwuit successor), plain HTTP | `127.0.0.1:6167` |
| Caddy | TLS termination, Matrix `.well-known`, Element web | `:61643`, plus `:8448` for federation |
| `tlsrouter` | SNI routing on `:443` → Caddy | `matrix.xsfx.dev`, `www.matrix.xsfx.dev` |
| Element web | Self-hosted client | <https://www.matrix.xsfx.dev> |
| mautrix bridges | Appservices (Telegram, WhatsApp, Signal, Slack) | `127.0.0.1:8080/29318/29328/29338` |
| `livekit` | SFU: carries the media for calls | `127.0.0.1:7880` (signalling), UDP `50100-50200` |
| `lk-jwt-service` | Exchanges a Matrix token for a LiveKit JWT | `127.0.0.1:8081` |
| TURN (in `livekit`) | Relay for clients that can't reach the SFU directly | UDP `3478`, TURN/TLS on `turn.xsfx.dev:443`, relay UDP `50300-60000` |

The client API and federation endpoints are the same Caddy site on two ports, so
there is a single Let's Encrypt certificate for `matrix.xsfx.dev` (the `www.`
host is its own site and gets its own). Federation is open
(`allow_federation = true`) and inbound on `:8448`, with discovery served as
`.well-known` by Caddy because tuwunel does not serve it.

State lives in `/var/lib/tuwunel` (RocksDB + media) and
`/var/lib/mautrix-<bridge>/` (session DB + generated config), all under restic's
daily backup.

## Adding a Matrix user

**Registration is permanently closed** (`allow_registration = false`) and stays
that way. Accounts are created from the admin room; you need to be a server
admin (currently `@marv:matrix.xsfx.dev`, the first user).

1. In Element, open the **admin room** (created on tuwunel's first startup; pin
   it if it keeps getting lost).
2. Create the account:

   ```
   !admin users create-user <username> [password]
   ```

   Omit the password to have one generated. Run `!admin users --help` for flags.
3. Hand over the credentials and log in at <https://www.matrix.xsfx.dev>.

Useful follow-ups in the same room:

| Command | Does |
| --- | --- |
| `!admin users list-users` | List local accounts |
| `!admin users reset-password <user> [password]` | Reset a password |
| `!admin users make-user-admin <user>` | Grant server-admin rights |
| `!admin users deactivate <user>` | Deactivate (leaves their rooms by default) |
| `!admin --help` | Full command list |

Nothing in Nix changes when you add a user.

## Connecting a user to the bridges

A new account can use **every** bridge without touching this repo: the
permissions map in `matrix/default.nix` grants

```nix
bridgePermissions = {
  "@marv:${domain}" = "admin";
  "${domain}" = "user";   # any local account
  "*" = "relay";          # federated users, relay only
};
```

so every user on `matrix.xsfx.dev` is allowed out of the box. Only an
**admin**-level bridge user differs, and that means editing that map.

| Bridge | Service | DM this bot | Appservice port | Auth |
| --- | --- | --- | --- | --- |
| Telegram | `mautrix-telegram` | `@telegrambot:matrix.xsfx.dev` | `8080` | `API_ID`/`API_HASH` from sops — currently blocked, see below |
| WhatsApp | `mautrix-whatsapp` | `@whatsappbot:matrix.xsfx.dev` | `29318` | QR pairing |
| Signal | `mautrix-signal` | `@signalbot:matrix.xsfx.dev` | `29328` | QR pairing |
| Slack | `mautrix-slack` | `@slackbot:matrix.xsfx.dev` | `29338` | Token + `d` cookie |

For each bridge:

1. In Element, start a DM with the bot (e.g. `@whatsappbot:matrix.xsfx.dev`) and
   send `login`.
2. Follow the replies. Send `help` in that DM at any point — the bot's own help
   is authoritative.

Login flows differ per bridge:

- **WhatsApp** — `login` shows a QR code; scan it from WhatsApp → *Linked
  devices*.
- **Signal** — `login` shows a `sgnl://linkdevice?...` link/QR; open it on the
  phone that runs Signal.
- **Telegram** — `login` alone only asks *how*: reply `login qr`, `login phone`,
  `login bot` or `login manual`. `login qr` is what worked here.
- **Slack** — token login: `login token <xoxc-…> <xoxd-…>`. The `xoxc-` token
  comes from the Slack web app (`localStorage.localConfig_v2`), the `xoxd-` value
  is the `d` cookie from the same browser session. Both rotate — when Slack
  invalidates them the bridge stops sending, and the fix is to grab them again
  and re-run the login. Getting the cookie right is the fiddly part, not the
  token.

## Registering a new bridge

This is the part that is easy to get wrong. A bridge only works once its
appservice is registered with the homeserver, and tuwunel is **not** auto-detected
by the upstream mautrix modules (they know Synapse and `matrix-conduit` only), so
nothing is set up for you.

1. Add the bridge to `hosts/dipper/matrix/default.nix`, copying an existing block:

   ```nix
   services.mautrix-<bridge> = {
     enable = true;
     settings = {
       homeserver = {
         address = "http://127.0.0.1:${toString hsPort}";  # tuwunel, manual
         domain = domain;
       };
       # The URL tuwunel pushes events TO — this bridge's OWN listener, not the
       # homeserver port. Getting this wrong is the classic 404/401.
       appservice.address = "http://127.0.0.1:<the bridge's own port>";
       bridge.permissions = bridgePermissions;
     };
   };
   ```

   `bridge.permissions` accepts **`relay` < `user` < `admin`** for the Go
   (bridgev2) bridges. `full` is the legacy Python bridge's level and is
   rejected.

2. `sudo nixos-rebuild switch`. The bridge starts, and on first start generates
   `/var/lib/mautrix-<bridge>/<bridge>-registration.yaml` with its tokens. That
   file is only generated if absent, so the tokens persist across restarts.

3. Register it once, in the **admin room**: send the command with the
   registration YAML pasted in a code block directly below it.

   ````
   !admin appservices register
   ```
   <contents of /var/lib/mautrix-<bridge>/<bridge>-registration.yaml>
   ```
   ````

   Registration is persisted in tuwunel's database and needs no restart.
   Re-registering an existing ID replaces the old entry.

4. Verify, then log in:

   ```
   !admin appservices list-registered
   ```

   and DM the bot → `login`.

Other admin-room commands for appservices: `list-registered`,
`show-appservice-config <id>`, `unregister <id>`.

**If you change `appservice.address` or its port**, the stored registration still
holds the old URL. Unregister and register again so the `url` matches:

```
!admin appservices unregister <bridge-id>
```

then repeat step 3.

### Why not the declarative `appservice_dir`?

Tuwunel can load registration YAML from a directory (`global.appservice_dir`),
which would remove the manual paste. It was evaluated and rejected:

- files are only read **at startup**, so every new or changed registration needs
  a homeserver restart;
- the bridges write their registration `0600` into their own state directory
  under a dynamic user, so tuwunel cannot read it without a permission dance.

The admin room is the pragmatic path: no restart, no perms juggling, persisted in
the database.

## Calling (Element Call / MatrixRTC)

Group calls are end-to-end encrypted and carried by a **LiveKit** SFU; a Matrix
homeserver never touches the media. Config: `matrix/turn.nix`.

How one call connects:

1. The client learns the call focus. Element Web reads it from
   `/.well-known/matrix/client` (answered by Caddy, key `rtc_foci`); Element X
   reads `/_matrix/client/unstable/org.matrix.msc4143/rtc/transports` (tuwunel
   builds that from `global.well_known.livekit_url`).
2. The bundled Element Call widget (`widgets/element-call` inside element-web,
   so no separate host) POSTs `<focus>/sfu/get` →
   `https://matrix.xsfx.dev/livekit/jwt/sfu/get`. Caddy strips `/livekit/jwt` and
   hands it to lk-jwt, which returns a LiveKit JWT plus the SFU URL.
3. The client opens `wss://matrix.xsfx.dev/rtc` (Caddy → LiveKit `7880`), and the
   media then goes straight to the daemon: UDP `50100-50200` normally, or via
   TURN `3478` / TURN-TLS on `:443` / ICE-TCP `7881` when the network blocks it.

The TURN listener is LiveKit's own — there is deliberately **no coturn**. It only
serves LiveKit clients, which is all Element Call is, and it authenticates with
the same `livekit-key` already in sops.

Things that bite later:

- **`turn.xsfx.dev` is not about the A record.** It exists so TURN/TLS has its own
  SNI name: one `:443` slot routes to exactly one backend, and for this one that
  backend has to be LiveKit (Caddy can't terminate TLS for TURN, and LiveKit
  hardcodes `:443` when advertising the candidate). It is a CNAME to
  `matrix.xsfx.dev`, so it inherits any address change — including an AAAA, if one
  is ever added to `matrix.`.
- **The TURN cert comes from Caddy, not from `security.acme`.** Caddy already owns
  `:80` — it binds it for its own HTTP→HTTPS redirects — so a standalone ACME
  client cannot have that port, and `turn.xsfx.dev:443` belongs to LiveKit, so
  TLS-ALPN-01 is out as well. `turn.nix` therefore adds a certificate-only Caddy
  site for the name (HTTP-01 on `:80`, which is why port 80 must stay open) and
  hands Caddy's cert files to LiveKit as systemd credentials. Get that wrong and
  the ACME module's *self-signed* fallback is what LiveKit serves — a browser
  rejects it, so TURN/TLS dies silently while everything looks "active".
- **The certificate is awaited, not raced.** Caddy issues it asynchronously, so
`livekit-wait-turn-cert.service` holds LiveKit until both the `.crt` and `.key`
exist. That wait is bounded at 120s: a broken ACME setup then fails the deploy
with a plain-language message ("timed out waiting for Caddy to issue …") instead
of hanging, or dying with systemd's opaque `243/CREDENTIALS`.
- **After a renewal** LiveKit keeps the old cert until restarted (it reads the
  files only at start). Caddy renews ~30 days before expiry, so `systemctl restart
  livekit` is never urgent.
- **Ghost participants.** tuwunel lacks MSC4140, so a client that crashes or is
  force-quit can linger in the roster until its membership expires. The call
  itself is fine; the participant list is briefly wrong. tuwunel PR #555 fixes it
  and needs no config change here.
- Nothing in this section needs backing up: both daemons are stateless.

Checks:

```sh
systemctl status livekit lk-jwt-service
journalctl -u livekit -n 50
curl -s https://matrix.xsfx.dev/.well-known/matrix/client | jq .   # must list rtc_foci
```

That the TURN/TLS certificate is real (not the ACME module's self-signed
fallback) needs a client machine with `openssl` — dipper has no `openssl` CLI:

```sh
openssl s_client -connect turn.xsfx.dev:443 -servername turn.xsfx.dev </dev/null \
  | openssl x509 -noout -issuer -dates      # issuer must be Let's Encrypt, not "minica root ca"
```

## Secrets

Only Telegram needs a secret: `mautrix-telegram-env` (declared in
`hosts/dipper/secrets.nix`), holding `API_ID`/`API_HASH`. The Go bridge reads
config from the environment with `env_config_prefix = "MAUTRIX_TELEGRAM_"`, and
`__` encodes a `.` in the config path — so the variables are
`MAUTRIX_TELEGRAM_NETWORK__API_ID` and `MAUTRIX_TELEGRAM_NETWORK__API_HASH`.
A single underscore does **not** work: the bridge then fails with
`network_api_hash not found` while holding a perfectly valid value.

WhatsApp, Signal and Slack need no sops entry — their appservice tokens are
auto-generated (and persisted in the registration file), and authentication is
per-session via the bot.

**Telegram is currently disabled in practice**: `my.telegram.org` returns a
generic `ERROR` for this account (rate-limit/2FA related), so no `API_ID`/
`API_HASH` could be obtained. The service config is in place and correct; it
starts working as soon as the credentials exist.

## Troubleshooting

Start by reading the bridge log — it usually states the problem in one line:

```sh
systemctl list-units 'mautrix-*'
journalctl -u mautrix-whatsapp -f        # or -signal / -slack / -telegram
```

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Bridge `active` and `Bridge started`, but nothing works; log has `No user logins found` / state `UNCONFIGURED` | The bridge never logged into the remote network. This is *healthy but unpaired*, not broken. | DM the bot → `login`, complete the pairing flow. |
| Bridge unit `failed` with `start-limit-hit`; the bot never answers at all | The appservice is not registered: log has `as_token was not accepted` or `401 Unknown access token`. A silent bot is the *symptom*. | Register it in the admin room (see above), then restart the unit. |
| `404`/`401` from the homeserver while registering | `appservice.address` is wrong — it must be the bridge's own listener port, and the registered `url` must match it. | Fix the address, redeploy, `!admin appservices unregister <id>`, register again. |
| `network_api_hash not found` despite a valid secret | Env var name wrong: it must use `__` for `.` (`..._NETWORK__API_HASH`). | Fix the var name in the sops env file. |
| Bridge stops sending on Slack after a while | Slack rotated the `xoxc-` token / `d` cookie. | `login token <xoxc-…> <xoxd-…>` again in the `@slackbot` DM. |
| Clicking an attachment in Element web does nothing — no download, no error | `/usercontent/` (the sandboxed iframe that turns the blob into a download) is serving the SPA shell instead of Element's 425-byte wrapper. Caddy's `try_files` probes files only, so a directory request falls through to `/index.html`. | The `www.` site needs `try_files {path} {path}/index.html /index.html` (see `matrix/default.nix`). Check with `curl -s https://www.matrix.xsfx.dev/usercontent/` — it must be the small wrapper loading `../bundles/<hash>/usercontent.js`, not the ~4.6 KB app HTML. |
| Login command seems ignored — no visible answer | The bot *did* reply; the answer is a notice in the DM. Telegram in particular asks which flow you want. | Scroll the DM, or reply `login qr`. |
| Call button missing, or "no MatrixRTC transport" | The client can't find the focus: `rtc_foci` missing from `/.well-known/matrix/client` (Element Web) or `well_known.livekit_url` unset on tuwunel (Element X). | Check the curl above; both come from Nix, so a deploy fixes it. |
| `livekit` failed, `status=243/CREDENTIALS` | The certificate was missing at unit start, so the gate before it was skipped or is broken. | `systemctl status livekit-wait-turn-cert` — if that timed out, Caddy could not issue: check `turn.xsfx.dev` resolves and port 80 is reachable, then `systemctl restart livekit`. Note the gate is *inactive (dead)* after a successful run by design: it re-checks on every LiveKit start, so `Result=success` is the thing to look at, not the state. |
| `livekit` active but TURN/TLS clients still fail | The credential held a cert the client rejects — usually the ACME module's self-signed fallback from an older config. | Check the issuer with the `openssl s_client` command above. |
| Call connects for some people but not others; media never starts | NAT or a filtered network. TURN/TLS on `:443` and ICE-TCP `7881` are the fallbacks — check they're reachable, and that `turn.xsfx.dev` still resolves. | `openssl s_client -connect turn.xsfx.dev:443 -servername turn.xsfx.dev` should complete the handshake. |

All of it is covered by restic's daily backup (see
[`backup.nix`](../hosts/dipper/backup.nix)): `/var/lib/tuwunel` and every
`/var/lib/mautrix-<bridge>` directory. A restore therefore does not require
re-pairing the bridges.
