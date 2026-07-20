_: {
  # Upstream Anubis (proof-of-work anti-scraper) in front of Forgejo.
  #
  # Request path: caddy (TLS + defender + badbots) -> anubis :8923 -> forgejo
  # 127.0.0.1:3000. Anubis challenges browser-like traffic regardless of source
  # IP, which closes the gap caddy-defender can't: its range blocks only cover
  # cloud/datacenter IPs, so the residential-IP archive scraper walked past it.
  # git clone / go-get send non-browser User-Agents and pass Anubis's default
  # policy untouched.
  #
  # TCP loopback instead of the module's default unix socket, so caddy's `caddy`
  # user can reach it without being added to anubis's DynamicUser group. No
  # secret is needed: Anubis auto-generates an ephemeral signing key (challenge
  # cookies just re-issue on restart). DIFFICULTY defaults to 4 and
  # policy.useDefaultBotRules defaults to true (Anubis's built-in AI-bot rules).
  services.anubis.instances.forgejo.settings = {
    TARGET = "http://127.0.0.1:3000";
    BIND = "127.0.0.1:8923";
    BIND_NETWORK = "tcp";
  };
}
