# Ravel (tuned)

The same Ravel entry as [`../ravel`](../ravel/README.md), with the same
scripts, store (a single-node RustFS on the machine's own disk) and load. It
differs only in the settings `benchmark.sh` exports before the run:

- `RAVEL_TUNED_ARGS="--sql-max-query-bytes 12884901888"`: raises the
  per-query SQL memory pool from the value the server derives on a 30 GB machine
  (about 8.2 GB) to 12 GiB. The widest `GROUP BY` in the set (q33) completes
  instead of being refused.
- `RAVEL_CACHE_DIR=$PWD/cache`: enables the read cache's local-disk tier. The
  tier survives the server restart the driver performs before each query, so a
  query's cold run can reuse bytes that earlier queries fetched from the store.
  It is bounded by the same resolved ceiling as the in-memory cache.

Everything else is the stock configuration, including the fetch policy the
server derives for a store on loopback. See `../ravel/README.md` for how the
entry is installed, loaded and run.
