_: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."restic_repo_file" = { };
  sops.secrets."restic_pass_file" = { };
}
