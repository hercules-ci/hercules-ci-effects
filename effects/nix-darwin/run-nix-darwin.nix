{ effects, mkEffect, lib, openssh, path }:

let
  docUrl = "https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/runnixdarwin";

  isRequired = param: throw ''
    runNixDarwin: the argument ${param} wasn't specified. You must pass either:
     - nix-darwin, {nixpkgs or pkgs}, system and configuration,
     - or config

    See ${docUrl}
  '';
  mutExMsg = this: that: ''
    runNixDarwin: the argument ${this} is mutually exclusive with ${that}.

    See ${docUrl}
  '';
in

# See https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/runnixdarwin
  # or docs/modules/ROOT/pages/reference/nix-functions/runNixDarwin.adoc
args@{
  # Configuration parameters
  nix-darwin ? isRequired "nix-darwin"
, configuration ? isRequired "configuration"
, nixpkgs ? null
, pkgs ? null
, system ? isRequired "system"
, config ? (import nix-darwin ({
    inherit system;
    configuration = if args?pkgs then {
      imports = [
        { imports = [ configuration ]; }
        # Apparent bug in nix-darwin; we need this
        { _module.args.pkgs = lib.mkForce pkgs; }
      ];
    } else configuration;
  }
  // lib.filterAttrs (k: v: v != null) { inherit pkgs nixpkgs; }
  // lib.optionalAttrs (args?pkgs && !args?nixpkgs) { nixpkgs = pkgs.path; }
  )).config
, # Deployment parameters
  ssh
, # Misc, optional
  passthru ? { }
, ...
}:
let _config = config;
in
let
  config = if _config?config.system.build.toplevel then _config.config else _config;

  suffix =
    if args ? name
    then "-${args.name}"
    else if config.networking.hostName or null == null
    then ""
    else "-${config.networking.hostName}";

  toplevel = config.system.build.toplevel;

  profilePath = config.system.profile;

  mutEx = this: that: lib.throwIf (args?${this} && args?${that}) (mutExMsg this that);

in

mutEx "config" "configuration"
mutEx "config" "nixpkgs"
mutEx "config" "nix-darwin"
mutEx "config" "system"
mutEx "config" "pkgs"

mkEffect (removeAttrs args [ "configuration" "ssh" "config" "system" "nix-darwin" "nixpkgs" "pkgs" ] // {
  name = "nix-darwin${suffix}";
  inputs = [ openssh ];
  dontUnpack = true;
  passthru = passthru // {
    prebuilt = toplevel // { inherit config; };
    inherit config;
  };
  effectScript = ''
    ${effects.ssh ssh ''
      set -eu
      echo >&2 "remote nix version:"
      nix-env --version >&2
      if [ "$USER" != root ] && [ ! -w $(dirname "${profilePath}") ]; then
        sudo nix-env -p ${profilePath} --set ${toplevel}
      else
        nix-env -p ${profilePath} --set ${toplevel}
      fi
      ${toplevel}/sw/bin/darwin-rebuild activate
    ''}
  '';
})
