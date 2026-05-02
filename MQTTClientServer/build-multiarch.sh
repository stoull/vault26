#!/bin/bash
set -e

IMAGE_NAME="stoull/mqtt_client"
TAG="0.3"
CACHE_DIR="${HOME}/buildx-cache/mqtt_client"

# 确保缓存目录存在
mkdir -p "$CACHE_DIR"

echo "Building multi-arch image for $IMAGE_NAME:$TAG"

# 确保使用正确的构建器
docker buildx create --name multiarch --use --bootstrap 2>/dev/null || true

# 方法A：构建并推送多架构镜像
echo "Building and pushing multi-arch image..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t $IMAGE_NAME:$TAG \
  -t $IMAGE_NAME:latest \
  --push .

# 方法B：同时构建本地可用的arm64版本
echo "Building local arm64 version..."
#docker buildx build \
#  --platform linux/arm64 \
#  -t $IMAGE_NAME:$TAG-arm64 \
#  --load .

echo "Done!"
echo "Multi-arch image pushed to Docker Hub"
echo "Local amd64 image available as $IMAGE_NAME:$TAG-amd64"

# 验证
echo "Verifying local image:"
docker images | grep $IMAGE_NAME
