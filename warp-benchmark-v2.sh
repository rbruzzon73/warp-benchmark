##################################################################
#                                                                #
#      run-warp-benchmark-v2.sh - version 2.0 - Jan 9, 2026      #
#                                                                #
#       -- New version with GET, PUT and Mixed tests. --         # 
#       -- Image changed to: quay.io/minio/warp:latest --        #
#                                                                #
###################### rbruzzon@redhat.com #######################

#!/bin/bash -xv
set -e

# --- CONFIGURATION ---
NAMESPACE="warp-benchmark"
OBC_NAME="warp-benchmark-bucket"
STORAGE_CLASS="openshift-storage.noobaa.io"
LOG_PREFIX="custom-run"

# Warp Benchmark Settings
WARP_CONCURRENT=10         # Number of concurrent operations
WARP_OBJ_SIZE="1536KiB"    # Object size
WARP_GET_OBJECTS=100       # Number of objects for GET/MIXED benchmark
BENCHMARK_PAUSE="10s"       # Time to sleep between benchmarks

# Durations
WARP_DURATION_PUT="30s"    # Duration for PUT benchmark
WARP_DURATION_GET="30s"    # Duration for GET benchmark
WARP_DURATION_MIXED="30s"  # Duration for MIXED benchmark

# Mixed Ration (50 means 50%)
# Note: The amount of DELETE operations. Must be same or lower than WARP_MIXED_PUT_RATIO
WARP_MIXED_GET_RATIO=50        # Mixed Ratio: % of operations that are GETs (e.g. 50 = 50% R / 50% W)
WARP_MIXED_PUT_RATIO=50        # Mixed Ratio: % of operations that are GETs (e.g. 50 = 50% R / 50% W)
WARP_MIXED_DELETE_RATIO=0      # Mixed Ratio: % of operations that are DELETEs (e.g. 50 = 50% R / 50% W)
WARP_MIXED_STAT_RATIO=0        # Mixed Ratio: % of operations that are STATs(e.g. 50 = 50% R / 50% W)

# Mixed Ration check
if [ $((WARP_MIXED_GET_RATIO + WARP_MIXED_PUT_RATIO + WARP_MIXED_DELETE_RATIO + WARP_MIXED_STAT_RATIO)) -ne 100 ]; then
	echo "Error: The sum of ratios (GET, PUT, DELETE and STAT) is $((WARP_MIXED_GET_RATIO + WARP_MIXED_PUT_RATIO + WARP_MIXED_DELETE_RATIO + WARP_MIXED_STAT_RATIO ))."
    echo "They must sum up to exactly 100."
    exit 1
fi
if [ "$WARP_MIXED_DELETE_RATIO" -gt "$WARP_MIXED_PUT_RATIO" ]; then
    echo "Error: DELETE ratio ($WARP_MIXED_DELETE_RATIO) cannot be higher than PUT ratio ($WARP_MIXED_PUT_RATIO)."
    exit 2
fi

#
# Main
#
echo "--- Starting Warp Benchmark Automation ---"
echo "Settings: Concurrent=$WARP_CONCURRENT, Size=$WARP_OBJ_SIZE"
echo "Mixed Ratio: $WARP_MIXED_GET_RATIO% GETs - $WARP_MIXED_PUT_RATIO% PUTs - $WARP_MIXED_DELETE_RATIO% DELETEs - $WARP_MIXED_STAT_RATIO% STATs"
echo "Pause between benchmarks: $BENCHMARK_PAUSE"

# 1. Create Namespace
echo "[1/11] Creating namespace '$NAMESPACE'..."
if ! oc get project $NAMESPACE >/dev/null 2>&1; then
    oc new-project $NAMESPACE
else
    echo "Namespace '$NAMESPACE' already exists. Switching to it."
    oc project $NAMESPACE
fi

# 2. Create ObjectBucketClaim (OBC)
echo "[2/11] Creating ObjectBucketClaim..."
cat <<EOF | oc apply -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: $OBC_NAME
  namespace: openshift-storage
spec:
  generateBucketName: warp-bucket
  storageClassName: $STORAGE_CLASS
EOF

# 3. Wait for OBC to be Bound
echo "[3/11] Waiting for OBC to be bound (provisioning bucket)..."
while [[ $(oc get obc $OBC_NAME -n openshift-storage -o jsonpath='{.status.phase}') != "Bound" ]]; do
    echo "Waiting for bucket provisioning..."
    sleep 5
done
echo "OBC is Bound."

# 4. Extract Secrets
echo "[4/11] Extracting credentials..."
AWS_ACCESS_KEY_ID=$(oc get secret $OBC_NAME -n openshift-storage -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
AWS_SECRET_ACCESS_KEY=$(oc get secret $OBC_NAME -n openshift-storage -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
S3_ENDPOINT=$(oc get configmap $OBC_NAME -n openshift-storage -o jsonpath='{.data.BUCKET_HOST}')
BUCKET_NAME=$(oc get configmap $OBC_NAME -n openshift-storage -o jsonpath='{.data.BUCKET_NAME}')

echo "Endpoint: $S3_ENDPOINT"
echo "Bucket:   $BUCKET_NAME"

# 5. Delete old Warp Pod
echo "[5/11] Clenup old Warp Running Pod"
if oc get pod warp-runner -n $NAMESPACE > /dev/null 2>&1; then
    echo "Deleting old 'warp-runner' pod..."
    oc delete pod warp-runner -n $NAMESPACE --grace-period=0 --force > /dev/null 2>&1
    # We wait to ensure the name is free
    oc wait --for=delete pod/warp-runner -n $NAMESPACE --timeout=60s
    echo "Old pod removed."
fi

# 6. Create Warp Pod
echo "[6/11] Deploying Warp Runner Pod..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: warp-runner
  namespace: $NAMESPACE
spec:
  containers:
  - name: warp
    image: quay.io/minio/warp:latest
    command: ["/bin/sh", "-c", "sleep infinity"]
    env:
      - name: AWS_ACCESS_KEY_ID
        value: "$AWS_ACCESS_KEY_ID"
      - name: AWS_SECRET_ACCESS_KEY
        value: "$AWS_SECRET_ACCESS_KEY"
      - name: S3_ENDPOINT
        value: "$S3_ENDPOINT"
      - name: BUCKET_NAME
        value: "$BUCKET_NAME"
      - name: LOG_PREFIX
        value: "$LOG_PREFIX"
      - name: WARP_CONCURRENT
        value: "$WARP_CONCURRENT"
      - name: WARP_OBJ_SIZE
        value: "$WARP_OBJ_SIZE"
      - name: WARP_GET_OBJECTS
        value: "$WARP_GET_OBJECTS"
      - name: WARP_DURATION_PUT
        value: "$WARP_DURATION_PUT"
      - name: WARP_DURATION_GET
        value: "$WARP_DURATION_GET"
      - name: WARP_DURATION_MIXED
        value: "$WARP_DURATION_MIXED"
      - name: WARP_MIXED_GET_RATIO
        value: "$WARP_MIXED_GET_RATIO"
      - name: WARP_MIXED_PUT_RATIO
        value: "$WARP_MIXED_PUT_RATIO"
      - name: WARP_MIXED_DELETE_RATIO
        value: "$WARP_MIXED_DELETE_RATIO"
      - name: WARP_MIXED_STAT_RATIO
        value: "$WARP_MIXED_STAT_RATIO"
  restartPolicy: Never
EOF

echo "Waiting for Pod to be Ready..."
oc wait --for=condition=Ready pod/warp-runner -n $NAMESPACE --timeout=120s

# 7. Run GET Benchmark
echo "[7/11] Running GET Benchmark..."
echo "---------------------------------------------------"

oc exec -n $NAMESPACE warp-runner -- /bin/sh -c '
    GET_FILE="${LOG_PREFIX}-get-$(date +%Y%m%d-%H%M%S)"
    echo ">>> Starting GET Benchmark ($WARP_DURATION_GET)..."
    echo "    Saving to: ${GET_FILE}.json.zst"

    ./warp get \
      --host "$S3_ENDPOINT" \
      --access-key "$AWS_ACCESS_KEY_ID" \
      --secret-key "$AWS_SECRET_ACCESS_KEY" \
      --bucket "$BUCKET_NAME" \
      --concurrent "$WARP_CONCURRENT" \
      --objects "$WARP_GET_OBJECTS" \
      --obj.size "$WARP_OBJ_SIZE" \
      --duration "$WARP_DURATION_GET" \
      --insecure \
      --benchdata "$GET_FILE" > /dev/null

    echo ">>> Analyzing GET Results:"
    ./warp analyze --analyze.v "${GET_FILE}.json.zst"
'
# 8. Pause 
echo "---------------------------------------------------"
echo "[8/11] Sleeping for $BENCHMARK_PAUSE before GET benchmark..."
sleep $BENCHMARK_PAUSE
echo "Resuming..."
echo "---------------------------------------------------"

# 9. Run PUT Benchmark
echo "[9/11] Running PUT Benchmark..."

oc exec -n $NAMESPACE warp-runner -- /bin/sh -c '
    PUT_FILE="${LOG_PREFIX}-put-$(date +%Y%m%d-%H%M%S)"
    echo ">>> Starting PUT Benchmark ($WARP_DURATION_PUT)..."
    echo "    Saving to: ${PUT_FILE}.json.zst"
    
    ./warp put \
      --host "$S3_ENDPOINT" \
      --access-key "$AWS_ACCESS_KEY_ID" \
      --secret-key "$AWS_SECRET_ACCESS_KEY" \
      --bucket "$BUCKET_NAME" \
      --concurrent "$WARP_CONCURRENT" \
      --obj.size "$WARP_OBJ_SIZE" \
      --duration "$WARP_DURATION_PUT" \
      --insecure \
      --benchdata "$PUT_FILE" > /dev/null

    echo ">>> Analyzing PUT Results:"
    ./warp analyze --analyze.v "${PUT_FILE}.json.zst"
'
# 10. Pause 2
echo "---------------------------------------------------"
echo "[10/11] Sleeping for $BENCHMARK_PAUSE before MIXED benchmark..."
sleep $BENCHMARK_PAUSE
echo "Resuming..."
echo "---------------------------------------------------"

# 11. Run MIXED Benchmark
echo "[11/11] Running MIXED Benchmark..."

oc exec -n $NAMESPACE warp-runner -- /bin/sh -c '
    MIXED_FILE="${LOG_PREFIX}-mixed-$(date +%Y%m%d-%H%M%S)"
    echo ">>> Starting MIXED Benchmark ($WARP_DURATION_MIXED)..."
    echo "    Ratio: $WARP_MIXED_GET_RATIO% GETs + $WARP_MIXED_PUT_RATIO% PUTs + $WARP_MIXED_DELETE_RATIO% DELETEs + $WARP_MIXED_STAT_RATIO% STATs "
    echo "    Saving to: ${MIXED_FILE}.json.zst"

    ./warp mixed \
      --host "$S3_ENDPOINT" \
      --access-key "$AWS_ACCESS_KEY_ID" \
      --secret-key "$AWS_SECRET_ACCESS_KEY" \
      --bucket "$BUCKET_NAME" \
      --concurrent "$WARP_CONCURRENT" \
      --obj.size "$WARP_OBJ_SIZE" \
      --objects "$WARP_GET_OBJECTS" \
      --duration "$WARP_DURATION_MIXED" \
      --get-distrib "$WARP_MIXED_GET_RATIO" \
      --put-distrib "$WARP_MIXED_PUT_RATIO" \
      --delete-distrib "$WARP_MIXED_DELETE_RATIO" \
      --stat-distrib "$WARP_MIXED_STAT_RATIO" \
      --insecure \
      --benchdata "$MIXED_FILE" > /dev/null

    echo ">>> Analyzing MIXED Results:"
    ./warp analyze --analyze.v "${MIXED_FILE}.json.zst"
'

echo "---------------------------------------------------"
echo "Benchmark Complete."
echo "---------------------------------------------------"
echo ""
echo "-------------------- NOTES ------------------------"
echo "---------------------------------------------------"
echo "The output includes throughput measured in MB/s showing data transfer rates."
echo "Operations per second display how many GET / PUT requests the system can handle."
echo "Latency percentiles show response times at p50, p90, p99, and p99.9 levels for operations."
echo "Links:"
echo "Throughput -> https://docs.min.io/enterprise/minio-warp/reference/#throughput"
echo "Operations per second -> https://docs.min.io/enterprise/minio-warp/reference/#operations-per-second"
echo "Latency percentiles -> https://docs.min.io/enterprise/minio-warp/reference/#latency-metrics"
