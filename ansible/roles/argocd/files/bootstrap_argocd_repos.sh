#!/bin/bash
# bootstrap_argocd_repos.sh
# Tạo hoặc cập nhật ArgoCD repository credential secrets.
# Biến bắt buộc (truyền qua environment từ Ansible):
#   KUBECONFIG, SECRETS_ENV_FILE, GIT_PLATFORM_REPO_URL,
#   CONFIG_REPO_URL, ARGOCD_NAMESPACE
set -euo pipefail

# Nạp biến nhạy cảm từ file môi trường (GHCR_USERNAME, GHCR_TOKEN, ...)
set -a
# shellcheck source=/dev/null
. "$SECRETS_ENV_FILE"
set +a

for secret_name in repo-git-platform repo-config; do
  case "$secret_name" in
    repo-git-platform) repo_url="$GIT_PLATFORM_REPO_URL" ;;
    repo-config)       repo_url="$CONFIG_REPO_URL" ;;
  esac

  kubectl create secret generic "$secret_name" \
    --namespace "$ARGOCD_NAMESPACE" \
    --from-literal=type=git \
    --from-literal=url="$repo_url" \
    --from-literal=username="$GHCR_USERNAME" \
    --from-literal=password="$GHCR_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl label secret "$secret_name" \
    --namespace "$ARGOCD_NAMESPACE" \
    argocd.argoproj.io/secret-type=repository \
    --overwrite
done
