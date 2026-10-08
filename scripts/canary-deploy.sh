#!/usr/bin/env bash
# ======= ======================================================================
# canary-deploy.sh <canary_percent>
#
# Implements a Canary release for the backend service.
#
# How it works:
#   Kubernetes Services load-balance evenly across every Pod that matches
#   their selector. So if a Service matches BOTH the "stable" and "canary"
#   Deployments (same "app: backend" label, different "track" label), the
#   percentage of traffic each version receives is simply:
#
#       canary_traffic % ≈ canary_replicas / (stable_replicas + canary_replicas)
#
#   This script takes a target canary percentage (0-100), calculates the
#   replica counts needed out of a fixed pool size (10 pods), and applies
#   them. Passing 0 removes canary traffic entirely (safe rollback);
#   passing 100 promotes the canary to be the only version running
#   (full rollout).
#
# Usage:
#   ./canary-deploy.sh 10    # 10% canary / 90% stable
#   ./canary-deploy.sh 50    # 50% canary / 50% stable
#   ./canary-deploy.sh 100   # promote canary fully
#   ./canary-deploy.sh 0     # rollback canary to 0%
#
# Required env vars: BACKEND_IMAGE_FULL (new/canary image),
#                     KUBE_NAMESPACE_PROD
# =============================================================================
set -euo pipefail

CANARY_PERCENT="${1:-10}"
NAMESPACE="${KUBE_NAMESPACE_PROD:-mern-production}"
POOL_SIZE=10 # total pods across stable + canary; tune for your cluster

if ! [[ "$CANARY_PERCENT" =~ ^[0-9]+$ ]] || [ "$CANARY_PERCENT" -lt 0 ] || [ "$CANARY_PERCENT" -gt 100 ]; then
  echo "Error: canary percent must be an integer between 0 and 100"
  exit 1
fi

CANARY_REPLICAS=$(( POOL_SIZE * CANARY_PERCENT / 100 ))
STABLE_REPLICAS=$(( POOL_SIZE - CANARY_REPLICAS ))

echo "==> Target split: ${CANARY_PERCENT}% canary"
echo "==> Replica counts: stable=${STABLE_REPLICAS}  canary=${CANARY_REPLICAS}"

echo "==> Ensuring namespace exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# On first run, STABLE_IMAGE_FULL may equal the currently-running stable image;
# reuse whatever is already deployed if not explicitly provided.
if [ -z "${STABLE_IMAGE_FULL:-}" ]; then
  STABLE_IMAGE_FULL=$(kubectl get deployment backend-stable -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "$BACKEND_IMAGE_FULL")
fi
export STABLE_IMAGE_FULL
export CANARY_IMAGE_FULL="${BACKEND_IMAGE_FULL}"

echo "==> Applying stable image:  $STABLE_IMAGE_FULL"
echo "==> Applying canary image:  $CANARY_IMAGE_FULL"

envsubst < k8s/canary-deployment.yaml | kubectl apply -n "$NAMESPACE" -f -

echo "==> Scaling deployments to match target split..."
kubectl scale deployment backend-stable -n "$NAMESPACE" --replicas="$STABLE_REPLICAS"
kubectl scale deployment backend-canary -n "$NAMESPACE" --replicas="$CANARY_REPLICAS"

if [ "$CANARY_REPLICAS" -gt 0 ]; then
  echo "==> Waiting for canary rollout to become healthy..."
  kubectl rollout status deployment/backend-canary -n "$NAMESPACE" --timeout=120s
fi

if [ "$CANARY_PERCENT" -eq 100 ]; then
  echo "==> Canary fully promoted. Updating stable deployment to the same image"
  echo "    and scaling canary back down to 0, so future releases start clean."
  kubectl set image deployment/backend-stable backend="$CANARY_IMAGE_FULL" -n "$NAMESPACE"
  kubectl scale deployment backend-stable -n "$NAMESPACE" --replicas="$POOL_SIZE"
  kubectl scale deployment backend-canary -n "$NAMESPACE" --replicas=0
fi

echo "==> Canary deployment step complete (${CANARY_PERCENT}% traffic to canary)."
echo "==> Monitor error rates / latency before increasing the percentage further."
