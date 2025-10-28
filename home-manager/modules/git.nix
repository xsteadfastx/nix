{ ... }:
{
  home.file.".gitconfig".text = ''
    [user]
      name = Marvin Preuss
      email = marvin@xsteadfastx.org

    [github]
      user = xsteadfastx

    [merge]
      tool = nvim

    [mergetool]
      keepBackup = false
      prompt = false

    [mergetool "nvim"]
      cmd = "nvim -d -c \"wincmd l\" -c \"norm ]c\" \"$LOCAL\" \"$MERGED\" \"$REMOTE\""
      layout = LOCAL,MERGED,REMOTE

    [alias]
      please = push --force-with-lease
      graph = log --oneline --abbrev-commit --all --graph --decorate --color
      hist = log --graph --pretty=format:'%Cred%h%Creset %s%C(yellow)%d%Creset %Cgreen(%cr)%Creset [%an]' --abbrev-commit --date=relative --all

    [credential]
      helper = gopass

    [push]
      followTags = true

    [filter "lfs"]
      process = git-lfs filter-process
      required = true
      clean = git-lfs clean -- %f
      smudge = git-lfs smudge -- %f
    [init]
      defaultBranch = main

    [sendemail]
      smtpserver = smtp.gmail.com
      smtpuser = xsteadfastx@gmail.com
      smtpencryption = tls
      smtpserverport = 587
      annotate = yes

    [rerere]
      enabled = true

    [diff]
      external = difft

    [difftool]
      prompt = false

    [pager]
      difftool = true

    [url "git@git.wobcom.de:"]
      insteadOf = https://git.wobcom.de/
  '';
}
