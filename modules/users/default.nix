{ ... }:
let
  sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINsnFFmG7PlPzMcjL/Buoy8P4hFUGOWGKB/UYdzWVVNu marv@xsfx.dev";
in
{
  nix.settings.trusted-users = [
    "marv"
  ];

  users.users = {
    marv = {
      isNormalUser = true;
      description = "marv";
      extraGroups = [
        "dialout"
        "docker"
        "lp"
        "networkmanager"
        "scanner"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ sshPubKey ];
      initialHashedPassword = "$6$wEP0BywDdq4ROL/a$aMVCPbK6zyvVOzsg121BYYVcPt0Jg33dz7lvrFojmlIeC5EBuiCgRT9.0/zh40SqUZem7p.s5SQTgcwYeZgDH0"; # notsafe
    };
  };
}
