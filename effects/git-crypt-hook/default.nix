{ stdenvNoCC, git-crypt, gnupg, git }:
stdenvNoCC.mkDerivation {
  name = "effects-git-crypt";

  # propagatedBuildInputs is a bit counterintuitive
  # See https://github.com/NixOS/nixpkgs/issues/64992#issuecomment-789956000
  propagatedBuildInputs = [ git-crypt gnupg git ];
  setupHook = ./git-crypt.sh;
  dontUnpack = true;
  dontBuild = true;
  dontInstall = true;
}
