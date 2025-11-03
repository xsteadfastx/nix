{ ... }:
{
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
    openFirewall = true;
    authorizedKeysFiles = [ "%h/.ssh/authorized_keys" ];
  };
}
