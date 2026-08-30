{
  imports = [
    ./flake-modules/module-argument.nix
    ./flake-modules/herculesCI-attribute.nix
    ./flake-modules/herculesCI-helpers.nix
    ./flake-modules/github-pages.nix
    ./flake-modules/github-releases
    ./effects/cargo/flake-module.nix
    ./effects/flake-update/flake-module.nix
    ./effects/netlify/flake-module.nix
  ];
}
