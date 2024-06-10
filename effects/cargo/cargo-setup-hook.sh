installCargoToken() {
  mkdir -p ~/.cargo
  cat >~/.cargo/credentials.toml <<EOF
[registry]
token = "$(readSecretString cargo .${cargoSecretField:-token})"

# When registryURL is set, we're using the "custom" registry.
[registries.custom]
token = "$(readSecretString cargo .${cargoSecretField:-token})"
EOF

}

preUserSetup+=("installCargoToken")
