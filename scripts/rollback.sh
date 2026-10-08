#!/usr/bin/env bash
# =============================================================================
# rollback.sh
#
# Instantly rolls back production traffic to whichever color is NOT
# currently live. Because blue-green deployments never delete the old
# version, rollback is just flipping the Service selector back — no
# rebuild, no redeploy, and it takes effect in seconds.
# =============================================================================
set -euo pipefail

NAMESPACE="${KUBE_NAMESPACE_PROD:-mern-production}"
SERVICE_NAME="backend-active"

CURRENT_COLOR=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.spec.selector.version}')

if [ "$CURRENT_COLOR" = "blue" ]; then
  ROLLBACK_COLOR="green"
else
  ROLLBACK_COLOR="blue"
fi

echo "==> Current live color: $CURRENT_COLOR"
echo "==> Rolling back to: $ROLLBACK_COLOR"

kubectl patch service "$SERVICE_NAME" -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"app\":\"backend\",\"version\":\"${ROLLBACK_COLOR}\"}}}"

echo "==> Rollback complete. Production traffic is now served by '$ROLLBACK_COLOR'."
