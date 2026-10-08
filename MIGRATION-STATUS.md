# Migration status: Turbo Vision classes

Updated: 2026-10-05 (local continuation)

## Branch and checkpoint

- Repository: `unxed/tv3`
- Branch: `classes/tv-classes`
- Current implementation checkpoint: `ce0276f`
- DN consumes this repository through its `tv` submodule.

The class migration is complete for the current tv3 tree: the class gate
passes, and the legacy class-pointer aliases were removed in `5e5bf11`.
`ce0276f` is the checkpoint before the separate UTF-8 source migration work.
Keep the safety tag `safety/pre-class-migration-20261005` before any bulk
rewrite.

DN's companion work continues on its separate
`classes/tv3-dependency` branch. It has pinned its local submodule to
`ce0276f`; do not merge the DN branch until the remaining DN construction,
destruction, and resource-loading paths pass the compiler and runtime gates.
