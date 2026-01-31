
# Warp Benchmark Script.

## General Notes:
   - The latest version of the script is warp-benchmark-v5.sh.
   - Benchmark tests were conducted in a test environment configured to align with OCP 4.16 and ODF 4.20.

## Notes warp-benchmark-V5.sh (LATEST version):
- warp image defined/assigned via WARP_IMAGE image.
- noobaa deduplication enable/disable via DEDUPLICATION_DISABLE variable.
- warp arguments can also be included via EXTRA variable.
- warp logs/summary redirected to main container log stream.

## Notes warp-benchmark-V4.sh (DEPRECATED version):
- noobaa deduplication disabled before starting any warp banchmark test as highlighted in the example below:
   ~~~
   #------ Executing Workload: mixed - 2026-01-29 15:09:47 -------#
   [1/15] Ratio check
   [2/15] Disable noobaa deduplication
   deployment.apps/noobaa-endpoint updated
   Waiting for all endpoints to update to value '0'...
   --- Waiting for pods to scale... (Found 9, Expected 7) ---
   --- Waiting for pods to scale... (Found 10, Expected 7) ---
   --- Waiting for pods to scale... (Found 11, Expected 7) ---
   --- Waiting for pods to scale... (Found 12, Expected 7) ---
   --- Waiting for pods to scale... (Found 12, Expected 7) ---
   --- Waiting for pods to scale... (Found 11, Expected 7) ---
   --- Waiting for pods to scale... (Found 9, Expected 7) ---
   SUCCESS - All 7 endpoints are now set to 0.
   [3/15] Warp General Settings:
   StorageClass=openshift-storage.noobaa.io - Concurrent=7 - Size=1536KiB - noobaa Deduplication Disabled=true
   PUT Duration: 30s - GET Duration: 30s - MIXED Duration: 30s
   MIXED Ratio: 50% GETs - 50% PUTs - 0% DELETEs - 0% STATs
   ... omitted ...
   ~~~

## Notes warp-benchmark-V3.sh (DEPRECATED version):
- script updated with the option to run only GET or PUT tests:
- Usage: ./warp-benchmark-v2.sh [mixed|standard|get|put|all]

## Notes warp-benchmark-v2.sh (DEPRECATED version):
- warp-benchmark-v2.sh delete the old warp POD and regenerate a new one before starting all benchmark tests.
- warp url image updated to: quay.io/minio/warp:latest
- Warp ObjectBucketClaim recreated before starting the benchmarcs.
- Usage: ./warp-benchmark-v2.sh [mixed|standard|all]
- V2 expands the Benchmark tests to include the Mixed scenario, based on the percentage of GETs and PUTs:
   ~~~
   # GET and PUT benchmarcs
   [1/11] Creating namespace 'warp-benchmark'...
   [2/11] Deleting and re-creating ObjectBucketClaim ...
   [3/11] Waiting for OBC to be bound (provisioning bucket)...
   [4/11] Extracting credentials...
   [5/11] Clenup old Warp Running Pod
   [6/11] Deploying Warp Runner Pod...
   [7/11] Running GET Benchmark...
   [8/11] Sleeping for 30s before PUT benchmark...
   [9/11] Running PUT Benchmark...
   # MIXED benchmarcs
   [1/11] Creating namespace 'warp-benchmark'...
   [2/11] Deleting and re-creating ObjectBucketClaim warp-benchmark-bucket-tf7w...
   [3/11] Waiting for OBC to be bound (provisioning bucket)...
   [4/11] Extracting credentials...
   [5/11] Clenup old Warp Running Pod
   [6/11] Deploying Warp Runner Pod...
   [10/11] Running MIXED Benchmark...
   [11/11] Benchmarks Complete.
   ~~~ 
   
## Notes warp-benchmark-v1.sh (DEPRECATED version):
- warp-benchmark.sh is based on Warp MinIO's S3 benchmarking tool designed to measure and analyze object storage performance. 
- The Warp tool generats realistic workloads and provides detailed performance metrics for S3-compatible storage systems.
- This warp-benchmark.sh script executes PUT and GET benchmarks that can be customized and adjusted to meet various requirements regarding size, duration, parallelism, and delay (sleep) between the two benchmark executions.  
- The operations are performed sequentially as detailed below:
   ~~~
   [1/8] Creating namespace 'warp-benchmark'...
   [2/8] Creating ObjectBucketClaim...
   [3/8] Waiting for OBC to be bound (provisioning bucket)...
   [4/8] Extracting credentials...
   [5/8] Deploying Warp Runner Pod...
   [6/8] Running PUT Benchmark...
   [7/8] Sleeping for 2m before GET benchmark...
   [8/8] Running GET Benchmark...
   ~~~
   
## Variables customizable in the run-warp-benchmark-v4.sh script.
The warp-benchmark scripts support the customization of the following Variables: 

       # Configuration:
       NAMESPACE="warp-benchmark"
       STORAGE_CLASS="openshift-storage.noobaa.io"
       WARP_IMAGE="quay.io/minio/warp:latest"
       LOG_PREFIX="custom-run"
       CLEAN_OBC_TIMEOUT="240s"   # Timeout for OBC deletion
       POD_ODB_PAUSE=30           # Sleep applied to ODB post deletion and POD post creation

       # Warp Benchmark Settings:
       WARP_CONCURRENT="7"
       # WARP_CONCURRENT=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.spec.multiCloudGateway.endpoints.maxCount}{"\n"}')
       WARP_OBJ_SIZE="1536KiB"    # Object size
       WARP_GET_OBJECTS=100       # Number of objects pre-allocated to supporte for GET/GET MIXED benchmarks
       BENCHMARK_PAUSE="10"       # Time to sleep between benchmarks (Integer)

       # Durations:
       WARP_DURATION_PUT="10m"    # Duration for PUT benchmark (seconds or minutes: e.g.: 30s, 60s, 10m ..)
       WARP_DURATION_GET="10m"    # Duration for GET benchmark (seconds or minutes: e.g.: 30s, 60s, 10m ..)
       WARP_DURATION_MIXED="10m"  # Duration for MIXED benchmark (seconds or minutes: e.g.: 30s, 60s, 10m ..)

       # Mixed Ration:
       # Note: The amount of DELETE operations. Must be same or lower than WARP_MIXED_PUT_RATIO
       WARP_MIXED_GET_RATIO=50        # Mixed Ratio: % of operations that are GETs.
       WARP_MIXED_PUT_RATIO=50        # Mixed Ratio: % of operations that are GETs.
       WARP_MIXED_DELETE_RATIO=0      # Mixed Ratio: % of operations that are DELETEs. 
       WARP_MIXED_STAT_RATIO=0        # Mixed Ratio: % of operations that are STATs.

       # noobaa endopoint deduplication_disabled [true|false]
       DEDUPLICATION_DISABLE="true"
       SEARCH_TERM="CONFIG_JS_MIN_CHUNK_AGE_FOR_DEDUP"
       CHECK_INTERVAL=10              # seconds

       ~~~
       
## Output details:
- The output includes throughput measured in MB/s showing data transfer rates. 
- Operations per second display how many GET / PUT requests the system can handle. 
- Latency percentiles show response times at p50, p90, p99, and p99.9 levels for operations.
- TTFB is the time from request was sent to the first byte was received.
- During the mixed operations phase, the command executes operations according to the configured distribution.
- The mixed benchmark randomly selects operation types based on the distribution percentages.

## Usefull links:
- [MinIO warp](https://docs.min.io/enterprise/minio-warp).
- [Throughput](https://docs.min.io/enterprise/minio-warp/reference/#throughput).
- [Operations per second](https://docs.min.io/enterprise/minio-warp/reference/#operations-per-second).
- [Latency percentiles](https://docs.min.io/enterprise/minio-warp/reference/#latency-metrics).

## Example of the output generated by "warp-benchmark-v2.sh all"
~~~
[root@dr-ocp-bastion-server ~]# ./warp-benchmark-v2.sh all
#------ Executing Workload: all - UTC 2026-01-09 21:47:33 -------#
Warp General Settings:
Concurrent=10 - Size=1536KiB
PUT Duration: 10m - GET Duration: 10m - MIXED Duration: 10m
MIXED Ratio: 50% GETs - 50% PUTs - 0% DELETEs - 0% STATs

# Start GET and PUT benchmarks
[1/11] Creating namespace 'warp-benchmark'...
Namespace 'warp-benchmark' already exists. Switching to it.
Already on project "warp-benchmark" on server "https://api.ocp4-dr.test.com:6443".
[2/11] Deleting and re-creating ObjectBucketClaim ...
Deleting found OBCs...
objectbucketclaim.objectbucket.io "warp-benchmark-bucket-fh8j" deleted
objectbucketclaim.objectbucket.io/warp-benchmark-bucket-ayxb created
[3/11] Waiting for OBC to be bound (provisioning bucket)...
Waiting for bucket provisioning...
OBC is Bound.
[4/11] Extracting credentials...
Endpoint: s3.openshift-storage.svc
Bucket:   warp-bucket-c25a7574-2932-4e1b-bf29-48a9071bbcdc
[5/11] Clenup old Warp Running Pod
Deleting old 'warp-runner' pod...
Old pod removed.
[6/11] Deploying Warp Runner Pod...
pod/warp-runner created
Waiting for Pod to be Ready...
pod/warp-runner condition met
..............................
[7/11] Running GET Benchmark...
---------------------------------------------------
>>> Starting GET Benchmark (10m)...
    Saving to: /tmp/custom-run-get-20260109-214848.json.zst
>>> Analyzing GET Results:


Report: GET (20567 reqs). Ran Duration: 9m57s, starting 21:49:05 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 10.
 * Average: 51.48 MiB/s, 34.32 obj/s (597s)
 * Reqs: Avg: 298.9ms, 50%: 272.3ms, 90%: 451.3ms, 99%: 719.4ms, Fastest: 59.1ms, Slowest: 2243.9ms, StdDev: 120.6ms
 * TTFB: Avg: 283ms, Best: 47ms, 25th: 200ms, Median: 257ms, 75th: 339ms, 90th: 434ms, 99th: 700ms, Worst: 2.211s StdDev: 120ms

Throughput, split into 597 x 1s:
 * Fastest: 109.7MiB/s, 73.15 obj/s (1s, starting 21:55:44 UTC)
 * 50% Median: 49.6MiB/s, 33.04 obj/s (1s, starting 21:55:46 UTC)
 * Slowest: 16.2MiB/s, 10.78 obj/s (1s, starting 21:49:03 UTC)


---------------------------------------------------
[8/11] Sleeping for 30 before PUT benchmark...
..............................Resuming...
---------------------------------------------------
[9/11] Running PUT Benchmark...
---------------------------------------------------
>>> Starting PUT Benchmark (10m)...
    Saving to: /tmp/custom-run-put-20260109-215938.json.zst
>>> Analyzing PUT Results:


Report: PUT (3724 reqs). Ran Duration: 9m58s, starting 21:59:43 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 10.
 * Average: 9.31 MiB/s, 6.20 obj/s (598s)
 * Reqs: Avg: 1683.8ms, 50%: 1715.2ms, 90%: 2104.9ms, 99%: 2355.9ms, Fastest: 495.4ms, Slowest: 4894.3ms, StdDev: 334.0ms

Throughput, split into 598 x 1s:
 * Fastest: 17.6MiB/s, 11.73 obj/s (1s, starting 22:00:11 UTC)
 * 50% Median: 8.9MiB/s, 5.96 obj/s (1s, starting 22:02:39 UTC)
 * Slowest: 3.2MiB/s, 2.15 obj/s (1s, starting 21:59:47 UTC)


# Start MIXED benchmarks
[1/11] Creating namespace 'warp-benchmark'...
Namespace 'warp-benchmark' already exists. Switching to it.
Already on project "warp-benchmark" on server "https://api.ocp4-dr.test.com:6443".
[2/11] Deleting and re-creating ObjectBucketClaim warp-benchmark-bucket-ayxb...
Deleting found OBCs...
objectbucketclaim.objectbucket.io "warp-benchmark-bucket-ayxb" deleted
objectbucketclaim.objectbucket.io/warp-benchmark-bucket-c7oc created
[3/11] Waiting for OBC to be bound (provisioning bucket)...
Waiting for bucket provisioning...
OBC is Bound.
[4/11] Extracting credentials...
Endpoint: s3.openshift-storage.svc
Bucket:   warp-bucket-d0067c7e-90a9-4357-bb9d-d4226e319e95
[5/11] Clenup old Warp Running Pod
Deleting old 'warp-runner' pod...
Old pod removed.
[6/11] Deploying Warp Runner Pod...
pod/warp-runner created
Waiting for Pod to be Ready...
pod/warp-runner condition met
..............................
[10/11] Running MIXED Benchmark...
---------------------------------------------------
>>> Starting MIXED Benchmark (10m)...
    Ratio: 50% GETs + 50% PUTs + 0% DELETEs + 0% STATs 
    Saving to: /tmp/custom-run-mixed-20260109-221134.json.zst
>>> Analyzing MIXED Results:


Report: GET (4017 reqs). Ran Duration: 9m58s, starting 22:11:50 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 10.
 * Average: 10.03 MiB/s, 6.69 obj/s (598s)
 * Reqs: Avg: 378.8ms, 50%: 335.1ms, 90%: 713.5ms, 99%: 971.8ms, Fastest: 28.1ms, Slowest: 2118.4ms, StdDev: 219.2ms
 * TTFB: Avg: 363ms, Best: 21ms, 25th: 203ms, Median: 318ms, 75th: 508ms, 90th: 697ms, 99th: 953ms, Worst: 2.106s StdDev: 216ms

Throughput, split into 598 x 1s:
 * Fastest: 23.9MiB/s, 15.93 obj/s (1s, starting 22:20:14 UTC)
 * 50% Median: 9.6MiB/s, 6.39 obj/s (1s, starting 22:21:40 UTC)
 * Slowest: 0.00 obj/s (1s, starting 22:21:20 UTC)

──────────────────────────────────

Report: PUT (4009 reqs). Ran Duration: 9m59s, starting 22:11:50 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 10.
 * Average: 10.02 MiB/s, 6.68 obj/s (599s)
 * Reqs: Avg: 1194.6ms, 50%: 1208.1ms, 90%: 1630.6ms, 99%: 2045.7ms, Fastest: 388.5ms, Slowest: 5016.2ms, StdDev: 322.7ms

Throughput, split into 599 x 1s:
 * Fastest: 17.3MiB/s, 11.51 obj/s (1s, starting 22:15:07 UTC)
 * 50% Median: 10.0MiB/s, 6.67 obj/s (1s, starting 22:14:06 UTC)
 * Slowest: 3.0MiB/s, 2.00 obj/s (1s, starting 22:21:26 UTC)


──────────────────────────────────

Report: Total (8026 reqs). Ran Duration: 9m59s, starting 22:11:50 UTC
 * Objects per request: 1. Size: 1572864 bytes. Concurrency: 10.
 * Average: 20.04 MiB/s, 13.36 obj/s (599s)

Throughput, split into 599 x 1s:
 * Fastest: 33.9MiB/s, 22.58 obj/s (1s, starting 22:12:51 UTC)
 * 50% Median: 20.1MiB/s, 13.42 obj/s (1s, starting 22:14:41 UTC)
 * Slowest: 4.0MiB/s, 2.65 obj/s (1s, starting 22:21:19 UTC)

#------ Phase: Cleanup -------#
Deleting OBC: warp-benchmark-bucket-c7oc...
objectbucketclaim.objectbucket.io "warp-benchmark-bucket-c7oc" deleted
pod "warp-runner" deleted
---------------------------------------------------
[11/11] Benchmarks Complete.
---------------------------------------------------

-------------------- NOTES ------------------------
---------------------------------------------------
The output includes throughput measured in MB/s showing data transfer rates.
Operations per second display how many GET / PUT requests the system can handle.
Latency percentiles show response times at p50, p90, p99, and p99.9 levels for operations.
Links:
Throughput -> https://docs.min.io/enterprise/minio-warp/reference/#throughput
Operations per second -> https://docs.min.io/enterprise/minio-warp/reference/#operations-per-second
Latency percentiles -> https://docs.min.io/enterprise/minio-warp/reference/#latency-metrics
~~~
