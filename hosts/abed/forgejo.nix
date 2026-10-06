_: {
  networking.firewall.allowedTCPPorts = [ 3000 ];

  services.forgejo = {
    enable = true;
    stateDir = "/var/lib/forgejo";
    database.type = "sqlite3";

    settings = {
      DEFAULT = {
        RUN_MODE = "prod";
      };

      server = {
        DISABLE_SSH = true;
        DOMAIN = "git.xsfx.dev";
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3000;
        PROTOCOL = "http";
        ROOT_URL = "https://git.xsfx.dev";
      };

      service = {
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        DISABLE_REGISTRATION = true;
      };

      # Bots were walking every commit SHA of large mirrors (e.g.
      # prometheus/cadvisor) and hitting /<repo>/archive/<sha>.bundle, making
      # Forgejo generate + cache a full-repo bundle per request. That filled
      # the disk (~9.7G under data/repo-archive) and wedged the leveldb queue.
      # The `dlSourceEnabled` guard on the /archive/* route 404s before any
      # generation when this is set, killing the storm at the door.
      repository = {
        DISABLE_DOWNLOAD_SOURCE_ARCHIVES = true;
      };

      # Minimal-instance trimming: Forgejo enables these subsystems by default,
      # but this box runs none of them. Turning them off shrinks the attack /
      # disk-fill surface on a small VM. Matches the common self-hosted pattern.
      # - actions: no CI runners are registered, so it does nothing but expose
      #   the Actions API/UI.
      # - packages: the package registry stores arbitrary blobs on the same
      #   disk anonymously-reachably (another disk-fill vector like archives).
      actions.ENABLED = false;
      packages.ENABLED = false;

      # Not used here; disable to reduce surface further.
      # - federation: ActivityPub federation (experimental, unused).
      # - api: hide the /api/swagger interactive docs endpoint.
      federation.ENABLED = false;
      api.ENABLE_SWAGGER = false;

      session = {
        COOKIE_SECURE = true;
      };
    };
  };
}
