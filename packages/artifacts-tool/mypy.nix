{ runCommand, python3Packages }:

runCommand "check-artifacts-tool-mypy"
{
  nativeBuildInputs = [ python3Packages.mypy ];
} ''
  cp ${./artifacts-tool.py} artifacts-tool.py
  mypy --strict --ignore-missing-imports \
    artifacts-tool.py

  touch $out
''
