{ effects, mkEffect, openssh, path }:

# Update a macOS machine with nix-darwin
#
# Use the nix-darwin installer first, then base the configuration off the
# generated ~/.nixpkgs/darwin-configuration.nix.
args@{

  # Source of nix-darwin
  nix-darwin,

  # Named parameters for call-ssh.nix
  ssh,

  # Configuration module; file path or module expression
  # Start with a copy of ~/.nixpkgs/darwin-configuration.nix
  configuration,

  # Source of nixpkgs
  nixpkgs ? path,

  # System, defaults to x86_64-darwin
  system,

  passthru ? {},

  # Remaining arguments are passed directly to mkEffect / mkDerivation
  ...
}:
let
  conf =
    import nix-darwin {
      inherit nixpkgs system configuration;
    };

  suffix =
    if args ? name
    then "-${args.name}"
    else if conf.config.networking.hostName == null
    then ""
    else "-${conf.config.networking.hostName}";
in
mkEffect (removeAttrs args ["configuration" "ssh"] // {
  name = "nix-darwin${suffix}";
  inputs = [ openssh ];
  dontUnpack = true;
  passthru = passthru // {
    prebuilt = conf.system // { inherit (conf) config; };
    inherit (conf) config;
  };
  effectScript = ''
    ${effects.ssh ssh ''
      ${conf.system}/sw/bin/darwin-rebuild activate
    ''}
  '';
})
