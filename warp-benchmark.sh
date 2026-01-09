##################################################################
#                                                                #
#        run-warp-benchmark.sh - version 2 - Jan 9, 2026         #
#                                                                #
###################### rbruzzon@redhat.com #######################

#!/bin/bash
set -e

# --- CONFIGURATION ---
NAMESPACE="warp-benchmark"
OBC_NAME="warp-benchmark-bucket"
STORAGE_CLASS="openshift-storage.noobaa.io"
LOG_PREFIX="custom-run"

# Warp Benchmark Settings
WARP_CONCURRENT=10         # Number of concurrent operations
WARP_OBJ_SIZE="1536KiB"    # Object size
WARP_DURATION_PUT="30s"    # Duration for PUT benchmark
WARP_DURATION_GET="30s"   # Duration for GET benchmark
WARP_GET_OBJECTS=500       # Number of objects for GET benchmark
BENCHMARK_PAUSE="2m"       # Time to sleep between PUT and GET

echo "--- Starting Warp Benchmark Automation ---"
echo "Settings: Concurrent=$WARP_CONCURRENT, Size=$WARP_OBJ_SIZE"
echo "Pause between benchmarks: $BENCHMARK_PAUSE"

# 1. Create Namespace
echo "[1/8] Creating namespace '$NAMESPACE'..."
if ! oc get project $NAMESPACE >/dev/null 2>&1; then
    oc new-project $NAMESPACE
else
    echo "Namespace '$NAMESPACE' already exists. Switching to it."
    oc project $NAMESPACE
fi

# 2. Create ObjectBucketClaim (OBC)
echo "[2/8] Creating ObjectBucketClaim..."
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
echo "[3/8] Waiting for OBC to be bound (provisioning bucket)..."
while [[ $(oc get obc $OBC_NAME -n openshift-storage -o jsonpath='{.status.phase}') != "Bound" ]]; do
    echo "Waiting for bucket provisioning..."
    sleep 5
done
echo "OBC is Bound."

# 4. Extract Secrets
echo "[4/8] Extracting credentials..."
AWS_ACCESS_KEY_ID=$(oc get secret $OBC_NAME -n openshift-storage -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
AWS_SECRET_ACCESS_KEY=$(oc get secret $OBC_NAME -n openshift-storage -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
S3_ENDPOINT=$(oc get configmap $OBC_NAME -n openshift-storage -o jsonpath='{.data.BUCKET_HOST}')
BUCKET_NAME=$(oc get configmap $OBC_NAME -n openshift-storage -o jsonpath='{.data.BUCKET_NAME}')

echo "Endpoint: $S3_ENDPOINT"
echo "Bucket:   $BUCKET_NAME"

# 5. Create Warp Pod
echo "[5/8] Deploying Warp Runner Pod..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: warp-runner
  namespace: $NAMESPACE
spec:
  containers:
  - name: warp
    image: minio/warp:latest
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
      # Pass benchmark settings as ENV vars
      - name: WARP_CONCURRENT
        value: "$WARP_CONCURRENT"
      - name: WARP_OBJ_SIZE
        value: "$WARP_OBJ_SIZE"
      - name: WARP_DURATION_PUT
        value: "$WARP_DURATION_PUT"
      - name: WARP_DURATION_GET
        value: "$WARP_DURATION_GET"
      - name: WARP_GET_OBJECTS
        value: "$WARP_GET_OBJECTS"
  restartPolicy: Never
EOF

echo "Waiting for Pod to be Ready..."
oc wait --for=condition=Ready pod/warp-runner -n $NAMESPACE --timeout=120s

# 6. Run PUT Benchmark
echo "[6/8] Running PUT Benchmark..."
echo "---------------------------------------------------"

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
    ./warp analyze "${PUT_FILE}.json.zst"
'

# 7. Pause
echo "---------------------------------------------------"
echo "[7/8] Sleeping for $BENCHMARK_PAUSE before GET benchmark..."
sleep $BENCHMARK_PAUSE
echo "Resuming..."
echo "---------------------------------------------------"

# 8. Run GET Benchmark
echo "[8/8] Running GET Benchmark..."

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
    ./warp analyze "${GET_FILE}.json.zst"
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
