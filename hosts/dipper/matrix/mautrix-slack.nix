{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    optional
    types
    ;

  cfg = config.services.mautrix-slack;

  dataDir = "/var/lib/mautrix-slack";
  settingsFormat = pkgs.formats.yaml { };
  settingsFile = settingsFormat.generate "mautrix-slack-config.yaml" cfg.settings;
  runtimeSettingsFile = "${dataDir}/config.yaml";
  runtimeRegistrationFile = "${dataDir}/slack-registration.yaml";
in
{
  options.services.mautrix-slack = {
    enable = mkEnableOption "mautrix-slack (Go bridgev2), a Matrix-Slack bridge";

    package = mkPackageOption pkgs "mautrix-slack" { };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing environment variables passed to the service (e.g. sops).
        The Go bridge reads config from env via `env_config_prefix`
        (`MAUTRIX_SLACK_*`). Note: `__` encodes a `.` in the config path (single `_` does not).
      '';
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;
      };
      default = { };
      description = ''
        {file}`config.yaml` for the Go mautrix-slack, see
        [example-config.yaml](https://docs.mau.fi/configs/mautrix-slack/latest).
      '';
    };

    serviceDependencies = mkOption {
      type = types.listOf types.str;
      default = optional config.services.matrix-tuwunel.enable "tuwunel.service";
      description = "Systemd units to require/wait for before starting the bridge.";
    };
  };

  config = mkIf cfg.enable {
    services.mautrix-slack.settings = {
      env_config_prefix = mkDefault "MAUTRIX_SLACK_";
      appservice = mkDefault {
        hostname = "127.0.0.1";
        port = 29338;
        # Where the homeserver pushes events to this bridge -> must match the
        # hostname:port the listener binds. Used as url in the registration.
        address = "http://127.0.0.1:29338";
        id = "slack";
        ephemeral_events = true;
        as_token = "";
        hs_token = "";
        username_template = "slack_{{.}}";
        bot = {
          username = "slackbot";
        };
      };
      database = mkDefault {
        type = "sqlite3-fk-wal";
        uri = "file:${dataDir}/mautrix-slack.db?_txlock=immediate";
      };
    };

    users.users.mautrix-slack = {
      isSystemUser = true;
      group = "mautrix-slack";
      home = dataDir;
      description = "mautrix-slack bridge user";
    };

    users.groups.mautrix-slack = { };

    systemd.services.mautrix-slack = {
      description = "mautrix-slack (Go bridgev2), a Matrix-Slack bridge";

      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ] ++ cfg.serviceDependencies;
      after = [ "network-online.target" ] ++ cfg.serviceDependencies;

      preStart = ''
        old_umask=$(umask)
        umask 0177
        cp '${settingsFile}' '${runtimeSettingsFile}'
        # generate the appservice registration once; then register it into tuwunel
        # via the admin room (`!admin appservices register`).
        if [ ! -f '${runtimeRegistrationFile}' ]; then
          ${getExe cfg.package} \
            --generate-registration \
            --config='${runtimeSettingsFile}' \
            --registration='${runtimeRegistrationFile}'
        fi
        # inject the generated as_token/hs_token back into the runtime config
        ${getExe pkgs.yq} -s \
          '.[0].appservice.as_token = .[1].as_token
           | .[0].appservice.hs_token = .[1].hs_token
           | .[0]' \
          '${runtimeSettingsFile}' '${runtimeRegistrationFile}' > '${runtimeSettingsFile}.tmp'
        mv '${runtimeSettingsFile}.tmp' '${runtimeSettingsFile}'
        umask $old_umask
      '';

      serviceConfig = {
        User = "mautrix-slack";
        Group = "mautrix-slack";
        Type = "simple";
        Restart = "always";
        WorkingDirectory = dataDir;
        StateDirectory = baseNameOf dataDir;
        UMask = "0027";
        EnvironmentFile = cfg.environmentFile;
        ExecStart = "${getExe cfg.package} --config='${runtimeSettingsFile}'";
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        LockPersonality = true;
        ProtectKernelLogs = true;
        ProtectKernelTunables = true;
        ProtectHostname = true;
        ProtectKernelModules = true;
        PrivateUsers = true;
        ProtectClock = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = "@system-service";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ ];
}
