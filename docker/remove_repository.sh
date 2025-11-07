set -euo pipefail

REPO="batch-processing-demo"
TAG="0.0.1-SNAPSHOT"
REG_URL="http://localhost:5000"

echo "=== Step 0: current catalog ==="
curl -s ${REG_URL}/v2/_catalog | jq . || true
echo

echo "=== Step 1: try to delete manifest via API (get digest) ==="
DIGEST=$(curl -sI -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "${REG_URL}/v2/${REPO}/manifests/${TAG}" 2>/dev/null \
  | awk -F': ' '/Docker-Content-Digest/{print $2}' | tr -d $'\r' || true)

if [ -n "$DIGEST" ]; then
  echo "Found digest: $DIGEST"
  echo "Deleting manifest ${REPO}:${TAG} -> ${DIGEST} ..."
  curl -v -X DELETE "${REG_URL}/v2/${REPO}/manifests/${DIGEST}" || true
else
  echo "No manifest digest found for ${REPO}:${TAG} (or manifest not accessible). Will proceed to wipe storage."
fi
echo

echo "=== Step 2: stop registry container ==="
docker stop registry 2>/dev/null || true
docker rm registry 2>/dev/null || true
sleep 1

echo "=== Step 3: garbage-collect (if registry data present) ==="
# 假設 registry 存放資料於 /var/lib/registry (如不同請調整)
if [ -d /var/lib/registry ]; then
  echo "Running registry garbage-collect (will mount host paths into ephemeral container)"
  docker run --rm -v /var/lib/registry:/var/lib/registry -v /etc/docker/registry:/etc/docker/registry \
    registry:2 bin/registry garbage-collect /etc/docker/registry/config.yml || true
  echo "Garbage-collect finished (if config.yml exists)."
else
  echo "/var/lib/registry not found on host; skipping garbage-collect."
fi
echo

echo "=== Step 4: wipe registry storage to ensure deletion (irreversible) ==="
if [ -d /var/lib/registry ]; then
  sudo rm -rf /var/lib/registry/* || true
  echo "/var/lib/registry/* removed"
else
  echo "No /var/lib/registry, skip wiping storage."
fi
echo

echo "=== Step 5: remove any skopeo dir/tars ==="
sudo rm -rf /var/lib/containers/storage/converted-image 2>/dev/null || true
rm -f batch-processing-demo*.tar myimage*.tar 2>/dev/null || true
echo "Removed skopeo artifacts if present."
echo

echo "=== Step 6: remove images from containerd (k8s.io and moby) ==="
if sudo ctr namespaces list | grep -q '^k8s.io'; then
  echo "Removing images in k8s.io..."
  sudo ctr -n k8s.io images list -q | while read -r img; do
    [ -n "$img" ] && echo " -> rm $img" && sudo ctr -n k8s.io images rm "$img" || true
  done
fi
if sudo ctr namespaces list | grep -q '^moby'; then
  echo "Removing images in moby..."
  sudo ctr -n moby images list -q | while read -r img; do
    [ -n "$img" ] && echo " -> rm $img" && sudo ctr -n moby images rm "$img" || true
  done
fi
echo

echo "=== Step 7: remove docker images related to repo (if any) ==="
docker rmi -f localhost:5000/${REPO}:${TAG} 2>/dev/null || true
docker rmi -f $(docker images | awk '/batch-processing-demo/ {print $3}') 2>/dev/null || true
docker image prune -af 2>/dev/null || true
echo

echo "=== Step 8: optionally recreate a clean registry (comment out if you don't want) ==="
docker run -d -p 5000:5000 --name registry --restart=always registry:2 || true
sleep 2

echo "=== Step 9: restart runtimes ==="
sudo systemctl restart crio || true
sudo systemctl restart containerd || true
sudo systemctl restart docker || true
sleep 2

echo "=== Verification ==="
echo "Registry catalog:"
curl -s ${REG_URL}/v2/_catalog || true
echo
echo "ctr k8s.io images list:"
sudo ctr -n k8s.io images list || true
echo
echo "ctr moby images list:"
sudo ctr -n moby images list || true
echo
echo "docker images:"
docker images || true
echo
echo "crictl images:"
crictl images || true

echo "=== Done: batch-processing-demo removed from registry and local images cleaned ==="
