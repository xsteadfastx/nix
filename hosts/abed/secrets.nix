_: {
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      "restic_repo_file" = { };
      "restic_pass_file" = { };
    };
  };
}
