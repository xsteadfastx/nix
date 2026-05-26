_: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."paperless-admin-password" = { };
  # sops.secrets."paperless-env" = {
  #   owner = "paperless";
  # };
}
