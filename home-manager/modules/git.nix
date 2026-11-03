{
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.unstable.git-lfs ];

  # Colours come from catppuccin.delta (its feature + bat's Catppuccin syntax
  # theme); it hooks into programs.delta, not a raw `delta` git section.
  programs.delta = {
    enable = true;
    package = pkgs.unstable.delta;
    enableGitIntegration = true;
    options = {
      dark = true;
      line-numbers = true;
      navigate = true;
      side-by-side = true;
    };
  };

  programs.git = {
    enable = true;
    package = pkgs.unstable.git;
    settings = {
      "filter \"lfs\"".clean = "git-lfs clean -- %f";
      "filter \"lfs\"".process = "git-lfs filter-process";
      "filter \"lfs\"".required = true;
      "filter \"lfs\"".smudge = "git-lfs smudge -- %f";
      "mergetool \"nvim\"".cmd =
        "nvim -d -c \"wincmd l\" -c \"norm ]c\" \"$LOCAL\" \"$MERGED\" \"$REMOTE\"";
      "mergetool \"nvim\"".layout = "LOCAL,MERGED,REMOTE";
      "mergetool \"diffview\"".cmd = "nvim -n -c \"DiffviewOpen\"";
      "url \"git@git.wobcom.de:\"".insteadOf = "https://git.wobcom.de";

      alias = {
        graph = "log --oneline --abbrev-commit --all --graph --decorate --color";
        hist = "log --graph --pretty=format:'%Cred%h%Creset %s%C(yellow)%d%Creset %Cgreen(%cr)%Creset [%an]' --abbrev-commit --date=relative --all";
        please = "push --force-with-lease";
      };
      credential.helper = "gopass";
      difftool.prompt = false;
      github.user = "xsteadfastx";
      init.defaultBranch = "main";
      merge.ff = false;
      merge.tool = "diffview";
      mergetool.keepBackup = false;
      mergetool.prompt = false;
      pager.difftool = true;
      pull.ff = true;
      push.followTags = true;
      rerere.enabled = true;
      sendemail = {
        annotate = "yes";
        smtpencryption = "tls";
        smtpserver = "smtp.gmail.com";
        smtpserverport = 587;
        smtpuser = "xsteadfastx@gmail.com";
      };
      user.email = "marvin@xsteadfastx.org";
      user.name = "Marvin Preuss";
    };
  };
}
