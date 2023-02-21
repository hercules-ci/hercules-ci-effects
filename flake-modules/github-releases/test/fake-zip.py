import json
from sys import argv

print(
  json.dumps(argv, indent=None, separators=(",", ":")),
  file=open("zip.log", "wt")
)
if len(argv) > 1:
    open(argv[1], 'wt')  # create the "archive"
