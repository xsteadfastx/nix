{ config, pkgs, ... }:

let
  # gitwatch runs headless as a system service, and git's global gopass helper
  # needs a TTY to unlock GPG. Answer git's credential prompts from the
  # sops-provisioned token instead.
  gitwatch-askpass = pkgs.writeShellScript "gitwatch-git-askpass" ''
    case "$1" in
      Username*) echo xsteadfastx ;;
      *) cat ${config.sops.secrets."vimwiki-git-token".path} ;;
    esac
  '';
in
{
  # ~/permanent/vimwiki is a plain git repo with a Forgejo remote. gitwatch
  # commits whenever a note changes and pushes to origin, pulling --rebase
  # first. Auth comes from the sops-provisioned `vimwiki-git-token` (Forgejo
  # access token, read+write): the unit's GIT_ASKPASS reads it, because git's
  # gopass helper needs a TTY for pinentry and a system service has none.
  # Hand-rolled rather than services.gitwatch: that module interpolates its
  # null `remote` (its own default) straight into the script and dies with
  # "cannot coerce null to a string", so a remote-less watch is unreachable
  # through it. Switch back once upstream handles a missing remote.
  systemd.services.gitwatch-notes = {
    description = "gitwatch for ~/permanent/vimwiki";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      git
      gitwatch
    ];
    serviceConfig.User = "marv";
    environment = {
      GIT_ASKPASS = "${gitwatch-askpass}";
      GIT_TERMINAL_PROMPT = "0";
      # An empty credential.helper resets the inherited list (gopass); without
      # the reset git tries gopass first and blocks instead of reaching
      # GIT_ASKPASS.
      GIT_CONFIG_COUNT = "1";
      GIT_CONFIG_KEY_0 = "credential.helper";
      GIT_CONFIG_VALUE_0 = "";
    };
    script = ''
      exec ${pkgs.gitwatch}/bin/gitwatch -r origin -R -m "chore(notes): autocommit %d" /home/marv/permanent/vimwiki
    '';
  };
}
