{ lib
, mkEffect
, netlify-cli
}:

args@{ content
, secretName ? throw ''effects.netlify: You must provide `secretName`, the name of the secret which holds the "${secretField}" field.''
, secretField ? "token"
, siteId
, productionDeployment ? false
, secretsMap ? {}
, extraDeployArgs ? [ ]
, ...
}:
let
  deployArgs = [
    "--dir=${content}"
    "--site=${siteId}"
    "--json"
  ] ++ lib.optionals productionDeployment [
    "--prod"
  ] ++ extraDeployArgs;
in
mkEffect (args // {
  inputs = [ netlify-cli ];
  secretsMap = { "netlify" = secretName; } // secretsMap;
  effectScript = ''

    # Install the token
    #
    # Netlify does not offer (or perhaps not document)
    # an alternate method of passing the token other than
    # the --auth flag, which is insecure. So we reverse
    # engineer the config file.
    # This effect can be tested with
    #
    #     nix develop
    #     hci effect run default.effects.tests.netlifyDeploy
    #
    mkdir -p ~/.config/netlify
    cat >~/.config/netlify/config.json <<EOF
    { "userId": "effects-netlifyDeploy-unknown-user-id"
    , "users": {
        "effects-netlifyDeploy-unknown-user-id": {
          "id": "effects-netlifyDeploy-unknown-user-id",
          "name": "effects.netlifyDeploy",
          "email": "effects.netlifyDeploy@example.com",
          "auth": {
            "token": "$(readSecretString netlify .${secretField})",
            "github": {}
          }
        }
      }
    }
    EOF

    netlify deploy \
      ${lib.escapeShellArgs deployArgs} | tee netlify-result.json
    # netlify does not print a newline after the json output, so we add it to keep the log tidy
    echo
  '';
})
