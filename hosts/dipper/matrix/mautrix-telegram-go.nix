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

  cfg = config.services.mautrix-telegram-go;

  dataDir = "/var/lib/mautrix-telegram";
  settingsFormat = pkgs.formats.yaml { };
  settingsFile = settingsFormat.generate "mautrix-telegram-config.yaml" cfg.settings;
  runtimeSettingsFile = "${dataDir}/config.yaml";
  runtimeRegistrationFile = "${dataDir}/telegram-registration.yaml";
in
{
  options.services.mautrix-telegram-go = {
    enable = mkEnableOption "mautrix-telegram (Go bridgev2), a Matrix-Telegram bridge";

    package = mkPackageOption pkgs "mautrix-telegram" { };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing environment variables passed to the service (e.g. sops).
        The Go bridge reads config from env via `env_config_prefix`
        (`MAUTRIX_TELEGRAM_NETWORK__API_ID`, `MAUTRIX_TELEGRAM_NETWORK__API_HASH`, ...).
        Note: `__` encodes a `.` in the config path (single `_` does not).
      '';
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;
      };
      default = { };
      description = ''
        {file}`config.yaml` for the Go mautrix-telegram, see
        [example-config.yaml](https://docs.mau.fi/configs/mautrix-telegram/latest).
      '';
    };

    serviceDependencies = mkOption {
      type = types.listOf types.str;
      default = optional config.services.matrix-tuwunel.enable "tuwunel.service";
      description = "Systemd units to require/wait for before starting the bridge.";
    };
  };

  config = mkIf cfg.enable {
    services.mautrix-telegram-go.settings = {
      env_config_prefix = mkDefault "MAUTRIX_TELEGRAM_";
      appservice = mkDefault {
        hostname = "127.0.0.1";
        port = 8080;
        # Where the homeserver pushes events to this bridge -> must match the
        # hostname:port the listener binds. Used as url in the registration.
        address = "http://127.0.0.1:8080";
        id = "telegram";
        ephemeral_events = true;
        as_token = "";
        hs_token = "";
        username_template = "telegram_{{.}}";
        bot = {
          username = "telegrambot";
        };
      };
      database = mkDefault {
        type = "sqlite3-fk-wal";
        uri = "file:${dataDir}/mautrix-telegram.db?_txlock=immediate";
      };
    };

    users.users.mautrix-telegram = {
      isSystemUser = true;
      group = "mautrix-telegram";
      home = dataDir;
      description = "mautrix-telegram bridge user";
    };

    users.groups.mautrix-telegram = { };

    systemd.services.mautrix-telegram = {
      description = "mautrix-telegram (Go bridgev2), a Matrix-Telegram bridge";

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
        User = "mautrix-telegram";
        Group = "mautrix-telegram";
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
