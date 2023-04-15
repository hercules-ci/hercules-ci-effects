{ lib
, mkEffect
, nodePackages
}:

{ content
, secretName ? throw ''effects.cloudflare-pages: You must provide `secretName`, the name of the secret which holds the "${secretField}" field.''
, secretField ? "token"
, projectName
, accountId
, branch ? null
, secretsMap ? { }
, extraDeployArgs ? [ ]
, ...
}@args:
let
  deployArgs = [
    "--project-name=${projectName}"
  ] ++ lib.optionals (branch != null) [
    "--branch=${branch}"
  ] ++ extraDeployArgs;
in
mkEffect (args // {
  name = "cloudflare-pages";
  inputs = [ nodePackages.wrangler ];
  secretsMap = { "cloudflare" = secretName; } // secretsMap;
  CLOUDFLARE_ACCOUNT_ID = accountId;
  effectScript = ''
    echo 1>&2 Running wrangler pages publish...
    export CLOUDFLARE_API_TOKEN="$(readSecretString cloudflare .${secretField})"
    wrangler pages publish ${content} ${lib.escapeShellArgs deployArgs}
  '';
})
