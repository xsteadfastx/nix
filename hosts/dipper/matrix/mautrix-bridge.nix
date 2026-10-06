# One Go-bridgev2 Matrix bridge, parameterised.
#
# The slack and telegram-go bridges are the same module 128 lines out of 155:
# same appservice settings shape, same config.yaml -> runtime copy, same
# --generate-registration + yq token injection in preStart, and the same 17
# systemd hardening directives. A fix landing in one copy silently missed the
# other -- that drift, not the line count, is why this is a factory.
#
# These stay local because nixpkgs has no *Go* bridge modules: its
# services.mautrix-telegram is the legacy Python one (config.json + telethon)
# and there is no mautrix-slack module at all.
{
  # systemd service / user / group / package name and /var/lib directory
  name,
  # homeserver-side bridge id, and the prefix for usernames + the bot account
  bridge,
  # appservice HTTP listener port (the homeserver pushes events here)
  port,
  # option name under `services`, where it differs from the service name
  optionName ? name,
  # per-bridge wording for the environmentFile docs, when the default is wrong
  envHint ? null,
}:
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

  cfg = config.services.${optionName};

  bridgeName = lib.toUpper (builtins.substring 0 1 bridge) + builtins.substring 1 (-1) bridge;
  envPrefix = "MAUTRIX_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] bridge)}_";
  envHintText =
    if envHint != null then
      envHint
    else
      "(`${envPrefix}*`). Note: `__` encodes a `.` in the config path (single `_` does not).";

  dataDir = "/var/lib/${name}";
  settingsFormat = pkgs.formats.yaml { };
  settingsFile = settingsFormat.generate "${name}-config.yaml" cfg.settings;
  runtimeSettingsFile = "${dataDir}/config.yaml";
  runtimeRegistrationFile = "${dataDir}/${bridge}-registration.yaml";

  description = "${name} (Go bridgev2), a Matrix-${bridgeName} bridge";
in
{
  options.services.${optionName} = {
    enable = mkEnableOption description;

    package = mkPackageOption pkgs name { };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing environment variables passed to the service (e.g. sops).
        The Go bridge reads config from env via `env_config_prefix`
        ${envHintText}
      '';
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;
      };
      default = { };
      description = ''
        {file}`config.yaml` for the Go ${name}, see
        [example-config.yaml](https://docs.mau.fi/configs/mautrix-${bridge}/latest).
      '';
    };

    serviceDependencies = mkOption {
      type = types.listOf types.str;
      default = optional config.services.matrix-tuwunel.enable "tuwunel.service";
      description = "Systemd units to require/wait for before starting the bridge.";
    };
  };

  config = mkIf cfg.enable {
    services.${optionName}.settings = {
      env_config_prefix = mkDefault envPrefix;
      appservice = mkDefault {
        hostname = "127.0.0.1";
        inherit port;
        # Where the homeserver pushes events to this bridge -> must match the
        # hostname:port the listener binds. Used as url in the registration.
        address = "http://127.0.0.1:${toString port}";
        id = bridge;
        ephemeral_events = true;
        as_token = "";
        hs_token = "";
        username_template = "${bridge}_{{.}}";
        bot = {
          username = "${bridge}bot";
        };
      };
      database = mkDefault {
        type = "sqlite3-fk-wal";
        uri = "file:${dataDir}/${name}.db?_txlock=immediate";
      };
    };

    users.users.${name} = {
      isSystemUser = true;
      group = name;
      home = dataDir;
      description = "${name} bridge user";
    };

    users.groups.${name} = { };

    systemd.services.${name} = {
      inherit description;

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
        User = name;
        Group = name;
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
}
