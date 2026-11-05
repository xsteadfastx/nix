{
  fetchFromGitHub,
  runCommand,
  python3,
  unzip,
}:

# DeDRM calibre plugins, built the way upstream builds its releases: upstream
# ships sources only (the newest release asset is v10.0.3 from 2022), and
# `make_release.py` splices `__calibre_compat_code.py` into every .py before
# zipping, so zipping the tree ourselves would produce a plugin that silently
# lacks the calibre-version compatibility shims.
#
# Output contains the plugin zips (DeDRM_plugin.zip, Obok_plugin.zip) plus the
# readmes; they are installed into ~/.config/calibre/plugins/ by
# home-manager/modules/desktop.nix.
runCommand "calibre-dedrm-plugin"
  {
    src = fetchFromGitHub {
      owner = "noDRM";
      repo = "DeDRM_tools";
      # master as of 2024-11-10, i.e. post-v10.0.9.
      rev = "7379b453199ed1ba91bf3a4ce4875d5ed3c309a9";
      hash = "sha256-Hq/DBYeJ2urJtxG+MiO2L8TGZ9/kLue1DXbG4/KJFhc=";
    };
    nativeBuildInputs = [
      python3
      unzip
    ];
  }
  ''
    cp -r --no-preserve=mode "$src"/. .
    python3 make_release.py
    # make_release.py drops the outer archive in $PWD and deletes release/.
    unzip -q DeDRM_tools.zip -d "$out"
  ''
