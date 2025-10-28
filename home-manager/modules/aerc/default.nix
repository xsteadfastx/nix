{
  lib,
  pkgsUnstable,
  ...
}:
{
  home.packages = [ pkgsUnstable.aerc ];

  home.file.".config/aerc/accounts.conf" = {
    text = ''
      [Personal]
      source            = imaps://xsteadfastx%40gmail.com@imap.gmail.com
      source-cred-cmd   = gopass show -o misc/mutt-gmail
      outgoing          = smtp://mail%40xsteadfastx.org@mail.your-server.de:587
      outgoing-cred-cmd = gopass show -o mail/marvin@xsteadfastx.org
      default           = INBOX
      from              = Marvin Preuss <marvin@xsteadfastx.org>
      copy-to           = [Gmail]/Sent Mail
      archive           = [Gmail]/All Mail
      cache-headers     = true
    '';
    target = ".config/aerc/accounts.conf";
    onChange = ''
      chmod 600 ~/.config/aerc/accounts.conf
    '';
    force = true;
  };

  home.activation.secureAercConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Securing ~/.config/aerc/accounts.conf..."
    target="$HOME/.config/aerc/accounts.conf"

    if [ -L "$target" ]; then
      echo "→ Replacing symlink with writable file"
      src="$(readlink -f "$target")"
      mkdir -p "$(dirname "$target")"
      rm -f "$target"
      cp -f "$src" "$target"
      chmod 600 "$target"
    elif [ -e "$target" ]; then
      echo "→ File already exists, adjusting permissions"
      chmod 600 "$target"
    else
      echo "⚠️ Warning: $target not found"
    fi
  '';

  xdg.configFile."aerc/aerc.conf".source = ./aerc.conf;

  xdg.configFile."aerc/dracula".text = ''
    #
    # aerc dracula styleset
    #
    # This styleset uses the terminal defaults as its fallback.
    # More information on how to configure the styleset can be found in
    # the aerc-stylesets(7) manpage. Please read the manual before
    # modifying or creating a styleset.
    #

    *.default=true

    default.bg=#20212b

    title.reverse=true
    header.bold=true
    header.fg=#8be9fd

    *error.bold=true
    error.fg=#ff5555
    warning.fg=#f1fa8c
    success.fg=#50fa7b

    statusline*.default=true
    statusline_default.reverse=true
    statusline_error.fg=#ff5555
    statusline_error.reverse=true
    statusline_default.fg=#303030
    statusline_default.bg=#af87ff

    dirlist_default.selected.fg=#f8f8f2
    dirlist_default.selected.bg=#44475a
    dirlist_recent.selected.fg=#44475a
    dirlist_recent.selected.bg=#f8f8f2
    dirlist_unread.fg=#50fa7b
    dirlist_unread.selected.fg=#50fa7b
    dirlist_unread.selected.bg=#44475a

    msglist_default.selected.fg=#44475a
    msglist_default.selected.bg=#f8f8f2
    msglist_unread.bold=true
    msglist_unread.fg=#50fa7b
    msglist_unread.selected.bg=#44475a
    msglist_read.selected.fg=#f8f8f2
    msglist_read.selected.bg=#44475a
    msglist_marked.fg=#f1fa8c
    msglist_marked.selected.fg=#f1fa8c
    msglist_marked.selected.bg=#44475a
    msglist_deleted.fg=#ff5555
    msglist_result.fg=#8be9fd
    msglist_result.selected.bg=#44475a

    msglist_deleted.selected.reverse=toggle

    completion_pill.reverse=true

    tab.reverse=true
    border.reverse = true
    tab.bg=#9c7adf
    tab.fg=#303030
    tab.selected.bg=#303030
    tab.selected.fg=#9c7adf
    border.fg=#20212b

    selector_focused.reverse=true
    selector_chooser.bold=true
  '';

  xdg.configFile."aerc/binds.conf".text = ''
    # Binds are of the form <key sequence> = <command to run>
    # To use '=' in a key sequence, substitute it with "Eq": "<Ctrl+Eq>"
    # If you wish to bind #, you can wrap the key sequence in quotes: "#" = quit
    <C-p> = :prev-tab<Enter>
    <C-PgUp> = :prev-tab<Enter>
    <C-n> = :next-tab<Enter>
    <C-PgDn> = :next-tab<Enter>
    \[t = :prev-tab<Enter>
    \]t = :next-tab<Enter>
    <C-t> = :term<Enter>
    ? = :help keys<Enter>
    <C-c> = :prompt 'Quit?' quit<Enter>
    <C-q> = :prompt 'Quit?' quit<Enter>
    <C-z> = :suspend<Enter>

    [messages]
    q = :prompt 'Quit?' quit<Enter>

    j = :next<Enter>
    <Down> = :next<Enter>
    <C-d> = :next 50%<Enter>
    <C-f> = :next 100%<Enter>
    <PgDn> = :next 100%<Enter>

    k = :prev<Enter>
    <Up> = :prev<Enter>
    <C-u> = :prev 50%<Enter>
    <C-b> = :prev 100%<Enter>
    <PgUp> = :prev 100%<Enter>
    g = :select 0<Enter>
    G = :select -1<Enter>

    J = :next-folder<Enter>
    <C-Down> = :next-folder<Enter>
    K = :prev-folder<Enter>
    <C-Up> = :prev-folder<Enter>
    H = :collapse-folder<Enter>
    <C-Left> = :collapse-folder<Enter>
    L = :expand-folder<Enter>
    <C-Right> = :expand-folder<Enter>

    v = :mark -t<Enter>
    <Space> = :mark -t<Enter>:next<Enter>
    V = :mark -v<Enter>

    T = :toggle-threads<Enter>
    zc = :fold<Enter>
    zo = :unfold<Enter>
    za = :fold -t<Enter>
    zM = :fold -a<Enter>
    zR = :unfold -a<Enter>
    <tab> = :fold -t<Enter>

    zz = :align center<Enter>
    zt = :align top<Enter>
    zb = :align bottom<Enter>

    <Enter> = :view<Enter>
    # d = :choose -o y 'Really delete this message' delete-message<Enter>
    d = :move [Gmail]/Trash<Enter>
    # D = :delete<Enter>
    a = :archive flat<Enter>
    A = :unmark -a<Enter>:mark -T<Enter>:archive flat<Enter>

    C = :compose<Enter>
    m = :compose<Enter>

    b = :bounce<space>

    rr = :reply -a<Enter>
    rq = :reply -aq<Enter>
    Rr = :reply<Enter>
    Rq = :reply -q<Enter>

    c = :cf<space>
    $ = :term<space>
    ! = :term<space>
    | = :pipe<space>

    / = :search<space>
    \ = :filter<space>
    n = :next-result<Enter>
    N = :prev-result<Enter>
    <Esc> = :clear<Enter>

    s = :split<Enter>
    S = :vsplit<Enter>

    pl = :patch list<Enter>
    pa = :patch apply <Tab>
    pd = :patch drop <Tab>
    pb = :patch rebase<Enter>
    pt = :patch term<Enter>
    ps = :patch switch <Tab>

    [messages:folder=Drafts]
    <Enter> = :recall<Enter>

    [view]
    / = :toggle-key-passthrough<Enter>/
    q = :close<Enter>
    i = :close<Enter>
    O = :open<Enter>
    o = :open<Enter>
    S = :save<space>
    | = :pipe<space>
    D = :delete<Enter>
    A = :archive flat<Enter>

    <C-l> = :open-link <space>

    f = :forward<Enter>
    rr = :reply -a<Enter>
    rq = :reply -aq<Enter>
    Rr = :reply<Enter>
    Rq = :reply -q<Enter>

    H = :toggle-headers<Enter>
    <C-k> = :prev-part<Enter>
    <C-Up> = :prev-part<Enter>
    <C-j> = :next-part<Enter>
    <C-Down> = :next-part<Enter>
    J = :next<Enter>
    <C-Right> = :next<Enter>
    K = :prev<Enter>
    <C-Left> = :prev<Enter>

    [view::passthrough]
    $noinherit = true
    $ex = <C-x>
    <Esc> = :toggle-key-passthrough<Enter>

    [compose]
    # Keybindings used when the embedded terminal is not selected in the compose
    # view
    $noinherit = true
    $ex = <C-x>
    $complete = <C-o>
    <C-k> = :prev-field<Enter>
    <C-Up> = :prev-field<Enter>
    <C-j> = :next-field<Enter>
    <C-Down> = :next-field<Enter>
    <A-p> = :switch-account -p<Enter>
    <C-Left> = :switch-account -p<Enter>
    <A-n> = :switch-account -n<Enter>
    <C-Right> = :switch-account -n<Enter>
    <tab> = :next-field<Enter>
    <backtab> = :prev-field<Enter>
    <C-p> = :prev-tab<Enter>
    <C-PgUp> = :prev-tab<Enter>
    <C-n> = :next-tab<Enter>
    <C-PgDn> = :next-tab<Enter>

    [compose::editor]
    # Keybindings used when the embedded terminal is selected in the compose view
    $noinherit = true
    $ex = <C-x>
    <C-k> = :prev-field<Enter>
    <C-Up> = :prev-field<Enter>
    <C-j> = :next-field<Enter>
    <C-Down> = :next-field<Enter>
    <C-p> = :prev-tab<Enter>
    <C-PgUp> = :prev-tab<Enter>
    <C-n> = :next-tab<Enter>
    <C-PgDn> = :next-tab<Enter>

    [compose::review]
    # Keybindings used when reviewing a message to be sent
    # Inline comments are used as descriptions on the review screen
    y = :send<Enter> # Send
    n = :abort<Enter> # Abort (discard message, no confirmation)
    v = :preview<Enter> # Preview message
    p = :postpone<Enter> # Postpone
    q = :choose -o d discard abort -o p postpone postpone<Enter> # Abort or postpone
    e = :edit<Enter> # Edit
    a = :attach<space> # Add attachment
    d = :detach<space> # Remove attachment

    [terminal]
    $noinherit = true
    $ex = <C-x>

    <C-p> = :prev-tab<Enter>
    <C-n> = :next-tab<Enter>
    <C-PgUp> = :prev-tab<Enter>
    <C-PgDn> = :next-tab<Enter>
  '';
}
