# Fleet classifier fixtures (CIP-000A)

Reserved volume-id band **`v99001`–`v99099`** for tests only — not real
PMLR volumes. Discovery still matches `^[vr]\d+$`.

| Repo | Role |
|---|---|
| `v99001` | Published, missing posts workflow |
| `v99002` | Published, matching `pmlint-posts.yml` |
| `v99003` | Published, custom workflow mentioning `check_posts` |
| `v99004` | Unpublished (skip for posts campaign) |
| `v99005` | Unpublished, missing intake workflow |
| `v99006` | Published (skip for intake campaign) |

Published fixtures use `.pmfleet-published` and/or `_posts/` so tests need no git remotes.
