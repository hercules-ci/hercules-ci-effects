{ mkEffect, curl, cacert }:

# A simple demonstration of an effect
# TODO: add authentication
args@{ name, url, file }:
mkEffect {
  name = "put-url-${name}";
  # inputs = [ curl ]; # already in default input
  dontUnpack = true;
  inherit file;
  effectScript = ''
    curl -XPUT --upload-file "$file" \
        --retry-max-time 600 --retry-connrefused --max-time 1200 \
        --location --fail \
        ${url}
  '';
}
