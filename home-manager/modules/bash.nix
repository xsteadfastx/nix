_: {
  # bash is the tty1 login shell -- the one that starts a session by hand -- and
  # it was the last shell configured by unmanaged drift: ~/.profile carried a
  # dead branch for the old imperative-nix install, and ~/.bashrc was a leftover
  # Debian skeleton whose /usr paths (lesspipe, dircolors, bash_completion,
  # /etc/debian_chroot) do not exist on NixOS, plus a broot launcher for a broot
  # that is not even installed.
  #
  # Both files are now Home Manager's. That matters beyond tidiness:
  # programs.bash.enable writes `source hm-session-vars.sh` into ~/.profile, and
  # only that makes home.sessionPath land at the *front* of PATH (it is sourced
  # after /etc/profile has set the system PATH). Without it ~/.local/bin does not
  # precede /run/current-system/sw/bin, and the `niri` wrapper in
  # ../niri/default.nix would never win over the real niri binary.
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.bash = {
    enable = true;

    # The four lines of the old .bashrc that actually did something. HM has
    # native options for all of them (it writes ~/.bash_history itself).
    historyControl = [ "ignoreboth" ];
    historySize = 2000;
    historyFileSize = 2000;
    shellOptions = [
      "histappend"
      "checkwinsize"
    ];
    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };
  };
}
