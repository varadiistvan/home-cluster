REPO=harbor.stevevaradi.me/stevevaradi/postgres-operator-rust

if [ "$#" -lt 1 ] || [ "$#" -gt 1 ]; then
  echo "Give version number and only version number"
  exit 1
fi

docker buildx build --platform="linux/arm64" \
  -f ./Dockerfile \
  --tag "${REPO}:$1" \
  --tag "${REPO}:latest" \
  --load \
  .

docker push "${REPO}:$1"
docker push "${REPO}:latest"
