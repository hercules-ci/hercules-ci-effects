{ lib
, mkEffect
, cargo
, cargoSetupHook
}:

# See docs/modules/ROOT/pages/reference/nix-functions/cargoPublish.adoc
args@{ secretName ? throw ''effects.cargo: You must provide `secretName`, the name of the secret which holds the "${secretField}" field.''
, secretField ? "token"
, secretsMap ? { }
, manifestPath ? "Cargo.toml"
, src
, extraPublishArgs ? [ ]
, registryURL ? null
, ...
}:
let
  # This must match the "custom" identifier in ./cargo-setup-hook.sh
  customRegistryIdentifier = "CUSTOM";
in
mkEffect (args // {
  buildInputs = [ cargoSetupHook ];
  inputs = [ cargo ];
  secretsMap = { "cargo" = secretName; } // secretsMap;

  env = args.env or { } // lib.optionalAttrs (registryURL != null) {
    "CARGO_REGISTRIES_${customRegistryIdentifier}_INDEX" = registryURL;
  };

  effectScript = ''
    cargo publish \
    ${lib.optionalString (manifestPath != null) "--manifest-path ${manifestPath}" } \
    ${lib.optionalString (registryURL != null) "--registry ${customRegistryIdentifier}"} \
    --target-dir "$(mktemp -d)" \
    ${lib.escapeShellArgs extraPublishArgs} \
    --no-verify
  '';
})

