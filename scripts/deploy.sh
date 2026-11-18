#!/usr/bin/env bash
# deploy.sh <image-tag> - run the app container, smoke test /health, roll back on failure.
set -euo pipefail

TAG="${1:?usage: deploy.sh <image-tag>}"
# shellcheck disable=SC1091
source /etc/app/app.env
STATE_FILE=/opt/app/current_tag
NAME=app

previous=""
if [[ -f "$STATE_FILE" ]]; then
  previous=$(cat "$STATE_FILE")
fi

run_container() {
  local tag=$1
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" --restart unless-stopped \
    -p "${APP_PORT}:8080" \
    -e ENVIRONMENT="$ENVIRONMENT" -e LOG_LEVEL=INFO \
    --read-only --security-opt no-new-privileges:true \
    --log-driver awslogs \
    --log-opt awslogs-region="$AWS_REGION" \
    --log-opt awslogs-group="$LOG_GROUP" \
    --log-opt awslogs-stream="$NAME" \
    "${IMAGE_REPO}:${tag}" >/dev/null
}

smoke_test() {
  for _ in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:${APP_PORT}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

echo "Deploying ${IMAGE_REPO}:${TAG} (previous: ${previous:-none})"
docker pull "${IMAGE_REPO}:${TAG}"
run_container "$TAG"
if smoke_test; then
  echo "$TAG" > "$STATE_FILE"
  echo "Deploy OK: $TAG"
  exit 0
fi

echo "Smoke test FAILED for $TAG" >&2
if [[ -n "$previous" ]]; then
  echo "Rolling back to $previous" >&2
  run_container "$previous"
  if smoke_test; then
    echo "Rollback OK: $previous" >&2
  else
    echo "Rollback FAILED" >&2
  fi
fi
exit 1
