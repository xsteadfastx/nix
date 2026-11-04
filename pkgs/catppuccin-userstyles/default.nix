{
  runCommand,
  lessc,
  python3,
  src,
  flavor,
  accent,
}:

# catppuccin/userstyles compiled into one userContent.css -- what Stylus does in
# the browser, done at build time. Each `.user.less` gets its `@var` header
# defaults as LESS variables (vars.py), with flavour and accent from the
# catppuccin config; light *and* dark flavour are both set to it, so a page
# matching `prefers-color-scheme: light` is not handed Latte. The remote
# `@import`s of the shared lib (also made inside the lib itself) are pointed at
# a local copy of it.
# A style that fails to compile fails the build. Every declaration is then made
# `!important` (important.py): as a user sheet it would otherwise lose to the
# page's own rules.
runCommand "catppuccin-userstyles-${flavor}-${accent}.css"
  {
    nativeBuildInputs = [
      lessc
      (python3.withPackages (ps: [ ps.tinycss2 ]))
    ];
  }
  ''
    cp -r --no-preserve=mode ${src}/lib lib
    unremote() { sed "s|https://userstyles.catppuccin.com/lib/|$PWD/lib/|" "$@"; }
    find lib -name '*.less' -exec sed -i "s|https://userstyles.catppuccin.com/lib/|$PWD/lib/|" {} +
    python3 ${./important.py} --test
    n=0
    for style in ${src}/styles/*/catppuccin.user.less; do
      name=$(basename "$(dirname "$style")")
      {
        python3 ${./vars.py} "$style" \
          lightFlavor=${flavor} darkFlavor=${flavor} accentColor=${accent}
        unremote "$style"
      } > "$name.less"
      lessc "$name.less" > "$name.css" \
        || { echo "catppuccin-userstyles: $name failed to compile" >&2; exit 1; }
      python3 ${./important.py} < "$name.css" >> $out
      n=$((n + 1))
    done
    [ "$n" -gt 100 ] || { echo "only $n styles found -- upstream layout changed?" >&2; exit 1; }
  ''
