#!/usr/bin/env bash
# deploy-and-push-use-dockerfile.sh
set -euo pipefail

### Config (可用環境變數覆蓋) ###
REGISTRY_HOST="${REGISTRY_HOST:-192.168.56.10}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REPO="${REPO:-batch-processing-demo}"
TAG="${TAG:-0.0.1-SNAPSHOT}"
JAR_PATH="${JAR_PATH:-./batch-processing-demo-0.0.1-SNAPSHOT.jar}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-./Dockerfile}"
### end config ###

IMAGE_NAME="${REGISTRY_HOST}:${REGISTRY_PORT}/${REPO}:${TAG}"
LOCAL_TAG="${REPO}:${TAG}"

echo "=== deploy-and-push-use-dockerfile.sh ==="
echo "Registry: ${REGISTRY_HOST}:${REGISTRY_PORT}"
echo "Target image: ${IMAGE_NAME}"
echo "Jar source: ${JAR_PATH}"
echo "Dockerfile: ${DOCKERFILE_PATH}"
echo

# checks
if [ ! -f "${JAR_PATH}" ]; then
  echo "ERROR: JAR not found at ${JAR_PATH}"
  exit 1
fi

if [ ! -f "${DOCKERFILE_PATH}" ]; then
  echo "ERROR: Dockerfile not found at ${DOCKERFILE_PATH}"
  exit 1
fi

# clean up old images
echo "Checking for old docker images..."
if docker images | grep -q "${REPO}.*${TAG}"; then
  echo "Removing old images for ${REPO}:${TAG} ..."
  docker rmi -f "${LOCAL_TAG}" >/dev/null 2>&1 || true
  docker rmi -f "${IMAGE_NAME}" >/dev/null 2>&1 || true
else
  echo "No old images found for ${REPO}:${TAG}."
fi
echo

# create temp build dir
TMP_BUILD_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_BUILD_DIR}"' EXIT

echo "Preparing build context in ${TMP_BUILD_DIR} ..."
cp "${DOCKERFILE_PATH}" "${TMP_BUILD_DIR}/Dockerfile"

COPY_SRC=$(awk 'BEGIN{IGNORECASE=1} /^[[:space:]]*COPY[[:space:]]+/ { print $2; exit }' "${DOCKERFILE_PATH}" || true)
if [ -z "${COPY_SRC}" ] || [ "${COPY_SRC}" = "-" ]; then
  echo "Warning: couldn't parse COPY source from Dockerfile, defaulting to app.jar"
  COPY_SRC="app.jar"
fi
COPY_SRC_BASENAME=$(basename "${COPY_SRC}")
cp "${JAR_PATH}" "${TMP_BUILD_DIR}/${COPY_SRC_BASENAME}"

echo "Build context files:"
ls -l "${TMP_BUILD_DIR}"

echo
echo "Building local docker image: ${LOCAL_TAG} ..."
docker build -t "${LOCAL_TAG}" "${TMP_BUILD_DIR}"

echo "Tagging ${LOCAL_TAG} -> ${IMAGE_NAME}"
docker tag "${LOCAL_TAG}" "${IMAGE_NAME}"

echo "Pushing ${IMAGE_NAME} ..."
set +e
docker push "${IMAGE_NAME}"
PUSH_RC=$?
set -e

if [ ${PUSH_RC} -ne 0 ]; then
  echo
  echo "ERROR: docker push failed (rc=${PUSH_RC})"
  echo "Common causes & checks:"
  echo "  1) Insecure registry? /etc/docker/daemon.json 需加入:"
  echo "     { \"insecure-registries\": [\"${REGISTRY_HOST}:${REGISTRY_PORT}\"] }"
  echo "  2) 確認 registry 在 ${REGISTRY_HOST}:${REGISTRY_PORT} 可達"
  echo "  3) 若 registry 在 k8s 並開 hostPort，請用 node IP"
  echo "  4) 若 registry 有 auth/TLS，確認 docker login / certs"
  exit ${PUSH_RC}
fi

kubectl set image deployment/batch-processing-demo-deployment batch-processing-demo=192.168.56.10:5000/batch-processing-demo:0.0.1-SNAPSHOT -n default

echo
echo "✅ SUCCESS: pushed ${IMAGE_NAME}"

echo
echo "=== finished ==="
