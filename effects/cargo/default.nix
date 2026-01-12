{
  lib,
  mkEffect,
  cargo,
  cargoSetupHook,
}:

# See docs/modules/ROOT/pages/reference/nix-functions/cargoPublish.adoc
args@{
  secretName ? throw ''effects.cargo: You must provide `secretName`, the name of the secret which holds the "${secretField}" field.'',
  secretField ? "token",
  secretsMap ? { },
  manifestPath ? "Cargo.toml",
  src,
  extraPublishArgs ? [ ],
  registryURL ? null,
  dryRun ? false,
  assertVersions ? { },
  ...
}:
let
  # This must match the "custom" identifier in ./cargo-setup-hook.sh
  customRegistryIdentifier = "CUSTOM";
in
mkEffect (
  builtins.removeAttrs args [ "assertVersions" ]
  // {
    buildInputs = lib.optional (!dryRun) cargoSetupHook;
    inputs = [ cargo ];
    secretsMap =
      lib.optionalAttrs (!dryRun) {
        "cargo" = secretName;
      }
      // secretsMap;

    env =
      args.env or { }
      // lib.optionalAttrs (registryURL != null) {
        "CARGO_REGISTRIES_${customRegistryIdentifier}_INDEX" = registryURL;
      };

    effectScript = ''
      hciQuote() {
        if [[ -z "$1" ]]; then echo -n \'\'; else echo -n "''${1@Q}"; fi
      }
      hciCheckCargoVersion() {
        local package="$1" expected="$2"
        local actual
        actual="$(
          cargo metadata --format-version 1 \
            ${lib.optionalString (manifestPath != null) "--manifest-path ${manifestPath}"} \
            | jq -r '.packages.[] | select (.name == $package) | .version' --arg package $package
        )"
        if [[ "$actual" != "$expected" ]]; then
          echo Version mismatch. Dumping metadata:
          cargo metadata --format-version 1 \
            ${lib.optionalString (manifestPath != null) "--manifest-path ${manifestPath}"} \
            | jq
          echo -e "\033[1;31mVersion mismatch for $package: expected $(hciQuote "$expected"), got $(hciQuote "$actual")\033[0m"
          exit 1
        fi
        echo "Version check passed for $package: $actual"
      }
      hciCheckAllCargoVersions() {
        local expected="$1"
        local packages
        packages="$(
          cargo metadata --format-version 1 \
            ${lib.optionalString (manifestPath != null) "--manifest-path ${manifestPath}"} \
            | jq -r '.packages.[].name'
        )"
        for package in $packages; do
          hciCheckCargoVersion "$package" "$expected"
        done
      }
      ${
        if builtins.isString assertVersions then
          "hciCheckAllCargoVersions ${lib.escapeShellArg assertVersions}"
        else
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              name: value:
              ''hciCheckCargoVersion ${
                lib.escapeShellArgs [
                  name
                  value
                ]
              }''
            ) assertVersions
          )
      }
      ${lib.optionalString dryRun ''
        echo
        # Bold blue text
        echo -e "\033[1;34mRunning in dry-run mode, not publishing.\033[0m"
        echo
      ''}
      cargo publish \
      ${lib.optionalString (manifestPath != null) "--manifest-path ${manifestPath}"} \
      ${lib.optionalString (registryURL != null) "--registry ${customRegistryIdentifier}"} \
      ${lib.optionalString dryRun "--dry-run"} \
      --target-dir "$(mktemp -d)" \
      ${lib.escapeShellArgs extraPublishArgs} \
      --no-verify
    '';
  }
)
