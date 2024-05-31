{ lib
, mkEffect
, cargo
, cargoSetupHook
, rustc
, clang
, llvmPackages
}:
args@{ secretName ? throw ''effects.cargo: You must provide `secretName`, the name of the secret which holds the "${secretField}" field.''
, secretField ? "token"
, secretsMap ? { }
, manifestPath ? "${src}/Cargo.toml"
, src
, targetDir ? "$(mktemp -d)"
, extraPublishArgs ? [ ]
, extraBuildInputs ? [ ]
, ...
}: mkEffect (args // {
  buildInputs = [ cargoSetupHook ];
  inputs = [
    cargo
    rustc
    llvmPackages.bintools
    clang
  ] ++ extraBuildInputs;
  secretsMap = { "cargo" = secretName; } // secretsMap;

  # This style of variable passing allows overrideAttrs and modification in
  # hooks like the userSetupScript.
  effectScript = ''
    cargo publish \
    ${lib.optionalString (manifestPath != null) "--manifest-path ${manifestPath}" } \
    --target-dir ${targetDir} \
    ${lib.escapeShellArgs extraPublishArgs} \
  '';
})

