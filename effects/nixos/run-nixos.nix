{ nixos
, lib
, mkEffect
, openssh
, nix
}:
let
  inherit (lib) optionalAttrs;
in
args@{
    modules ? throw "effects.runNixOS: you must provide either a modules or config parameter",
    config ? (nixos {
      imports = modules;
    }).config,
    toplevel ? config.system.build.toplevel,
    hostKey ? null,
    profile ? "/nix/var/nix/profiles/system",
    hostname,
    passthru ? {},
    ...
  }: mkEffect (args // {
    inherit hostname;
    name = "nixos-${args.name or hostname}";
    inputs = [ openssh nix ];
    effectScript = ''
      nix-copy-closure --use-substitutes --to "$hostname" ${toplevel}
      ssh "$hostname" "$remoteScript"
    '';
    remoteScript = ''
      set -euo pipefail
      nix-env -p ${profile} --set ${toplevel}
      ${toplevel}/bin/switch-to-configuration switch
    '';
    userSetupScript = ''
      writeSSHKey

      if [[ -n ''${hostKey+x} ]]; then
        echo "$hostname ''${hostKey}" >>~/.ssh/known_hosts
      fi
    '';
    passthru = {
      prebuilt = toplevel;
    } // passthru;

    dontUnpack = args.dontUnpack or true;
  } // optionalAttrs (hostKey != null) {
    inherit hostKey;
  })
