{ lib
, mkEffect
, netlify-cli
, netlifySetupHook
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
    "--json"
  ] ++ lib.optionals productionDeployment [
    "--prod"
  ] ++ extraDeployArgs;
in
mkEffect (args // {
  buildInputs = [ netlifySetupHook ];
  inputs = [ netlify-cli ];
  secretsMap = { "netlify" = secretName; } // secretsMap;
  netlifySecretField = secretField;
  NETLIFY_SITE_ID = siteId;
  effectScript = ''
    echo 1>&2 Running netlify deploy...
    netlify deploy \
      ${lib.escapeShellArgs deployArgs} | tee netlify-result.json
    # netlify does not print a newline after the json output, so we add it to keep the log tidy
    echo
  '';
})
