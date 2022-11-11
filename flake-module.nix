{
  imports = [
    ./flake-modules/module-argument.nix
    ./flake-modules/herculesCI-attribute.nix
    ./flake-modules/herculesCI-helpers.nix
    ./effects/flake-update/flake-module.nix
    ./effects/netlify/flake-module.nix
  ];
}
