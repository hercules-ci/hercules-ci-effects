{
  imports = [
    ./flake-modules/module-argument.nix
    ./flake-modules/herculesCI-attribute.nix
    ./flake-modules/herculesCI-helpers.nix
    ./flake-modules/github-pages.nix
    ./flake-modules/github-releases
    ./effects/flake-update/flake-module.nix
  ];
}
