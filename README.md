# shopware-home

The home repo for working on Shopware with agents, after Matt Pocock's [Home Repo pattern](https://aihero.dev/the-home-repo-pattern): which repos exist and how they connect, the shared skills, the setup.

Start with [AGENTS.md](AGENTS.md).
Setting up a machine: run `/setup-home` in an agent session here, or read [docs/setup/machine.md](docs/setup/machine.md).

```bash
git clone --recurse-submodules git@github.com:gweiermann/shopware-home.git ~/Documents/shopware-home
~/Documents/shopware-home/bin/install.sh --dry-run
```

Generic skills come from [gweiermann/skills](https://github.com/gweiermann/skills) as the `general/` submodule.
`full-stop` and `opus-loop` are adapted from Theo Browne's [tstack](https://github.com/t3dotgg/tstack) (MIT).
