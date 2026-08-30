#!/bin/bash
# Ravel: object-storage-native telemetry database, queried over SQL.
#
# Ravel keeps every durable byte in S3-compatible object storage; there is no
# local-disk storage mode. The bucket and credentials therefore have to be
# supplied before this runs. See README.md.
export BENCH_DOWNLOAD_SCRIPT="download-hits-parquet-single"
exec ../lib/benchmark-common.sh
