
installNetlifyToken() {
  # Netlify does not offer (or perhaps not document)
  # an alternate method of passing the token other than
  # the --auth flag, which is insecure. So we reverse
  # engineer the config file.
  mkdir -p ~/.config/netlify
  cat >~/.config/netlify/config.json <<EOF
{ "userId": "effects-netlifyDeploy-unknown-user-id"
, "users": {
    "effects-netlifyDeploy-unknown-user-id": {
      "id": "effects-netlifyDeploy-unknown-user-id",
      "name": "effects.netlifyDeploy",
      "email": "effects.netlifyDeploy@example.com",
      "auth": {
        "token": "$(readSecretString netlify .${netlifySecretField:-token})",
        "github": {}
      }
    }
  }
}
EOF

}

preUserSetup+=("installNetlifyToken")
