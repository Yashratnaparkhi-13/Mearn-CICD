#!/usr/bin/env bash
# =============================================================================
# blue-green-deploy.sh
#
# Implements a Blue-Green deployment to Kubernetes for the backend service.
#
# How it works:
#   1. Find out which color (blue/green) is currently LIVE by reading the
#      "backend-active" Service selector.
#   2. Deploy the NEW image to the IDLE color (the opposite one).
#   3. Wait for the idle deployment to become healthy (rollout status).
#   4. Run a quick smoke test against the idle color via the "backend-preview"
#      style port-forward / internal call.
#   5. Flip the "backend-active" Service selector to point at the new color.
#      This is the moment real user traffic moves to the new version, and it
#      is effectively instant (a single label swap).
#   6. The OLD color is left running (not deleted) so that rollback is just
#      flipping the selector back — no rebuild, no redeploy needed.
#
# Required env vars: BACKEND_IMAGE_FULL, KUBE_NAMESPACE_PROD
# =============================================================================
set -euo pipefail

NAMESPACE="${KUBE_NAMESPACE_PROD:-mern-production}"
SERVICE_NAME="backend-active"

echo "==> Ensuring namespace and secrets exist..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Determining currently LIVE color..."
CURRENT_COLOR=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "blue")

if [ "$CURRENT_COLOR" = "blue" ]; then
  IDLE_COLOR="green"
else
  IDLE_COLOR="blue"
fi

echo "==> Live color is '$CURRENT_COLOR'. Deploying new version to IDLE color '$IDLE_COLOR'."

# Apply the idle deployment with the new image
envsubst < "k8s/backend-deployment-${IDLE_COLOR}.yaml" | kubectl apply -n "$NAMESPACE" -f -

# Make sure both Services (active + preview) exist; ignore if already applied
kubectl apply -n "$NAMESPACE" -f k8s/backend-service-production.yaml

echo "==> Waiting for '$IDLE_COLOR' deployment to become healthy..."
kubectl rollout status "deployment/backend-${IDLE_COLOR}" -n "$NAMESPACE" --timeout=180s

echo "==> Pointing 'backend-preview' service at '$IDLE_COLOR' for smoke testing..."
kubectl patch service backend-preview -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"app\":\"backend\",\"version\":\"${IDLE_COLOR}\"}}}"

echo "==> Running smoke test against the preview service..."
kubectl run smoke-test-"$IDLE_COLOR" --rm -i --restart=Never --image=curlimages/curl:8.8.0 \
  -n "$NAMESPACE" -- curl -sf "http://backend-preview/health" \
  && echo "==> Smoke test PASSED" \
  || { echo "==> Smoke test FAILED — aborting, traffic stays on $CURRENT_COLOR"; exit 1; }

echo "==> Flipping production traffic from '$CURRENT_COLOR' to '$IDLE_COLOR'..."
kubectl patch service "$SERVICE_NAME" -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"app\":\"backend\",\"version\":\"${IDLE_COLOR}\"}}}"

echo "==> Blue-Green deployment complete. Live color is now '$IDLE_COLOR'."
echo "==> Old color '$CURRENT_COLOR' is still running for instant rollback."
echo "    To roll back: kubectl patch service $SERVICE_NAME -n $NAMESPACE -p '{\"spec\":{\"selector\":{\"version\":\"$CURRENT_COLOR\"}}}'"
