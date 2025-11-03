{ ... }:
let
  sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINsnFFmG7PlPzMcjL/Buoy8P4hFUGOWGKB/UYdzWVVNu marv@xsfx.dev";
in
{
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
    };
  };
}
