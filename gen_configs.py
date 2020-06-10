import os
from pathlib import Path

"""
%RPC_PORT%
%P2P_PORT%
%REST_PORT%
%SEED%
%MONIKER%
"""

with open("multiaccs.csv", "r") as data:
    multiaccs = data.read().split("\n")

with open("template.yml", "r") as temp_data:
    template = temp_data.read()

print(f'Multiaccs count: {len(multiaccs)}')
config_dir = "configs"
p          = Path('.')
RPC_START  = 26697
P2P_START  = 26696
REST_START = 1397
OFFSET     = 10


if not os.path.exists(config_dir):
    os.mkdir(config_dir)

for acc in multiaccs:
    if acc == "" or acc is None:
        continue

    moniker = acc.split(';')[0]
    seed    = acc.split(';')[1]

    new_tmpl = template\
        .replace("%RPC_PORT%",  str(RPC_START))\
        .replace("%P2P_PORT%",  str(P2P_START))\
        .replace("%REST_PORT%", str(REST_START))\
        .replace("%SEED%",      str(seed))\
        .replace("%MONIKER%",   str(moniker))

    config_path = p / config_dir / f'{moniker}.yml'
    print(config_path.resolve())

    with open(config_path.resolve(), 'w') as yml_file:
        yml_file.write(new_tmpl)

    RPC_START +=  OFFSET
    P2P_START +=  OFFSET
    REST_START += OFFSET









