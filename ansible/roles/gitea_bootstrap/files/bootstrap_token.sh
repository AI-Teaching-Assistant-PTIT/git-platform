#!/bin/bash
# bootstrap_token.sh
# Được gọi bởi Ansible với các biến truyền qua environment.
# Biến bắt buộc: NAMESPACE, GITEA_POD, USER_LIST, SERVICE_ACCOUNT,
#                SERVICE_ACCOUNT_EMAIL, TOKEN_NAME, TOKEN_SCOPES, KUBECONFIG
set -euo pipefail

run_gitea() {
  local escaped_args
  printf -v escaped_args ' %q' "$@"
  kubectl exec --namespace "$NAMESPACE" "$GITEA_POD" -- \
    /bin/su -s /bin/sh git -c \
    "gitea --config /data/gitea/conf/app.ini --work-path /data/gitea --custom-path /data/gitea${escaped_args}"
}

token="$(kubectl get secret webapp-secret --namespace "$NAMESPACE" \
  --output jsonpath='{.data.GITEA_TOKEN}' 2>/dev/null | base64 --decode || true)"
if [ -n "$token" ]; then
  printf 'unchanged\n'
  exit 0
fi

if printf '%s\n' "$USER_LIST" | \
  awk -v username="$SERVICE_ACCOUNT" 'NR > 1 && $2 == username { found=1 } END { exit !found }'; then
  printf 'GITEA_TOKEN chưa có trong webapp-secret nhưng service account đã tồn tại. Hãy chạy quy trình rotation tường minh.\n' >&2
  exit 1
fi

password="$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | cut -c1-48)"
[ "${#password}" -eq 48 ] || {
  printf 'Không thể tạo mật khẩu ngẫu nhiên cho service account Gitea.\n' >&2
  exit 1
}

run_gitea admin user create \
  --username "$SERVICE_ACCOUNT" \
  --password "$password" \
  --email "$SERVICE_ACCOUNT_EMAIL" \
  --must-change-password=false

token="$(run_gitea admin user generate-access-token \
  --username "$SERVICE_ACCOUNT" \
  --token-name "$TOKEN_NAME" \
  --scopes "$TOKEN_SCOPES" \
  --raw)"
[ -n "$token" ] || {
  printf 'Gitea không trả về access token sau khi tạo.\n' >&2
  exit 1
}

patch_json="$(printf '{"data":{"GITEA_TOKEN":"%s"}}' "$(printf '%s' "$token" | base64 -w 0)")"
kubectl patch secret webapp-secret --namespace "$NAMESPACE" \
  --type=merge \
  --patch "$patch_json"
printf 'created\n'
