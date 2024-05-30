{ lib
, mkEffect
, cargo
, cargoSetupHook
}:
args@{ secretName ? throw ''effects.cargo: You must provide `secretName`, the name of the secret which holds the "${secretField}" field.''
, secretField ? "token"
, secretsMap ? { }
, manifestPath ? null
, extraPublishArgs ? [ ]
, ...
}: mkEffect (args // {
  buildInputs = [ cargoSetupHook ];
  inputs = [ cargo ];
  secretsMap = { "cargo" = secretName; } // secretsMap;

  # This style of variable passing allows overrideAttrs and modification in
  # hooks like the userSetupScript.
  effectScript = ''
    cargo publish \
    ${lib.optionalString (manifestPath != null) "--manifest-path ${manifestPath}" }
    ${lib.escapeShellArgs extraPublishArgs}
  '';
})

