{ writers, ... }:

writers.writePython3Bin "artifacts-tool" {} (builtins.readFile ./artifacts-tool.py)
