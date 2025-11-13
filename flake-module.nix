{
  imports = [
    ./flake-modules/module-argument.nix
    ./flake-modules/herculesCI-attribute.nix
    ./flake-modules/herculesCI-helpers.nix
    ./flake-modules/github-pages.nix
    ./flake-modules/github-releases
    ./flake-modules/npm-release
    ./effects/flake-update/flake-module.nix
  ];
}
