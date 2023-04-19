import json
from sys import argv

print(
  json.dumps(argv, indent=None, separators=(",", ":")),
  file=open("gh.log", "wt")
)
