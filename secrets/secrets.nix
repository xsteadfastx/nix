let
  marvAge = "age1nve58jkqmp98qr3txj7hf6cdaqwkglc27c6m7urfl88y6ug2t4psh9x27t";
  users = [ marvAge ];
in
{
  "kodi-advancedsettings.xml".publicKeys = users;
  "kodi-passwords.xml".publicKeys = users;
  "kodi-sources.xml".publicKeys = users;
}
