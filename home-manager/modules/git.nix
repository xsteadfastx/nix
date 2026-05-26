{ pkgsUnstable, ... }:
let
  inherit (pkgsUnstable) git-lfs delta;
in
{
  home.packages = [
    git-lfs
    delta
  ];

  programs.git = {
    enable = true;
    package = pkgsUnstable.git;
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

      alias.graph = "log --oneline --abbrev-commit --all --graph --decorate --color";
      alias.hist = "log --graph --pretty=format:'%Cred%h%Creset %s%C(yellow)%d%Creset %Cgreen(%cr)%Creset [%an]' --abbrev-commit --date=relative --all";
      alias.please = "push --force-with-lease";
      core.pager = "delta";
      credential.helper = "gopass";
      delta.dark = true;
      delta.lineNumbers = true;
      delta.navigate = true;
      delta.side-by-side = true;
      delta.smoothScroll = true;
      delta.theme = "Dracula";
      difftool.prompt = false;
      github.user = "xsteadfastx";
      init.defaultBranch = "main";
      interactive.diffFilter = "delta --color-only";
      merge.ff = false;
      merge.tool = "diffview";
      mergetool.keepBackup = false;
      mergetool.prompt = false;
      pager.difftool = true;
      pull.ff = true;
      push.followTags = true;
      rerere.enabled = true;
      sendemail.annotate = "yes";
      sendemail.smtpencryption = "tls";
      sendemail.smtpserver = "smtp.gmail.com";
      sendemail.smtpserverport = 587;
      sendemail.smtpuser = "xsteadfastx@gmail.com";
      user.email = "marvin@xsteadfastx.org";
      user.name = "Marvin Preuss";
    };
  };
}
