{ ... }:
{
  sops.defaultSopsFile = ../secrets.yaml;
  sops.age.keyFile = "/home/marv/.age/nix.txt";
}
