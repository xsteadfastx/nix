{ nixosConfig, lib, ... }:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  home.file.".local/share/fonts" = {
    source = ./fonts;
    recursive = true;
  };

  # slashed zero for JetBrainsMono everywhere (i3 can't set font features itself)
  fonts.fontconfig.enable = true;
  fonts.fontconfig.configFile."jetbrains-zero" = {
    enable = true;
    text = ''
      <fontconfig>
        <match target="font">
          <test qual="any" name="family" compare="contains"><string>JetBrainsMono Nerd Font</string></test>
          <edit name="fontfeatures" mode="assign_replace">
            <string>zero</string>
          </edit>
        </match>
      </fontconfig>
    '';
  };
}
