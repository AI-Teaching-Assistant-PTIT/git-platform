# NITS Platform — Ansible

Tự động hoá cài đặt K8s platform bằng Ansible.

## Cấu trúc

```
ansible/
├── site.yml              # Master playbook (uninstall + install toàn bộ)
├── uninstall.yml         # Chỉ gỡ k3s
├── group_vars/
│   └── all.yml           # Biến chung (versions, passwords, ...)
├── inventory/
│   └── hosts.yml         # localhost single-node
└── roles/
    ├── k3s/              # Cài K3s
    ├── k3s_uninstall/    # Gỡ K3s
    ├── helm/             # Cài Helm
    ├── runtime_secrets/  # Tạo Kubernetes Secrets từ ../.env
    ├── gitea_bootstrap/  # Tạo service account/token Gitea sau khi sẵn sàng
    ├── cnpg/             # CloudNative PG operator
    └── argocd/           # ArgoCD + password + ApplicationSet
```

## Cài đặt Ansible

Trước khi chạy bất kỳ lệnh nào, bạn cần đảm bảo máy đã được cài đặt Ansible (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install -y ansible
```

## Trước khi chạy

Tạo/cập nhật `platform/.env` (file này đã được Git ignore). Ansible đọc file này trên máy deploy để tạo các Kubernetes Secret; không đưa plaintext secret vào Git.

Các biến bắt buộc:

```dotenv
POSTGRES_USER=            # phải là admin để khớp CNPG bootstrap và Gitea
POSTGRES_PASSWORD=
GITEA_ADMIN_USERNAME=
GITEA_ADMIN_PASSWORD=
GITEA_ADMIN_EMAIL=
MINIO_ROOT_USER=
MINIO_ROOT_PASSWORD=
MINIO_ACCESS_KEY=
MINIO_SECRET_KEY=
SECRET_KEY=
FIRST_SUPERUSER=
FIRST_SUPERUSER_PASSWORD=
CLOUDFLARE_TUNNEL_TOKEN=
GHCR_USERNAME=
GHCR_TOKEN=
GHCR_EMAIL=
```

Các biến tuỳ chọn (được đưa vào Secret dưới dạng rỗng nếu không khai báo):

```dotenv
SSO_CLIENT_ID=
SSO_SECRET=
SSO_DIRECTORY_ID=
```

## Gitea: tài khoản admin và Microsoft SSO

Role `runtime_secrets` đưa `GITEA_ADMIN_*` và `SSO_*` vào Secret `gitea-<namespace>`.
Container GitPTIT tự dùng các biến này khi khởi động để migrate database, tạo tài khoản
admin và tạo/cập nhật nguồn đăng nhập Microsoft — không cần bước cấu hình thủ công qua web.

- Bỏ trống cả ba biến `SSO_*` để tắt SSO; điền thiếu một biến sẽ làm container dừng với lỗi rõ ràng.
- Rotate client secret: sửa `SSO_SECRET` trong `.env`, chạy lại playbook rồi
  `kubectl rollout restart deployment/gitea-<namespace>`.
- Đổi mật khẩu admin sau lần tạo đầu không bị bootstrap ghi đè; muốn đặt lại phải dùng
  `gitea admin user change-password` trong pod.
- Redirect URI đăng ký trên Entra ID: `https://<GITEA__server__DOMAIN>/user/oauth2/Microsoft/callback`.

Chi tiết cơ chế bootstrap xem [../README.md](../README.md).

## Gitea integration token

Sau khi Argo CD đồng bộ Gitea, role `gitea_bootstrap` tự tạo service account `nits-integration`, tạo access token runtime và lưu trực tiếp vào `assistant-secret`. Token không cần có trước trong `.env` và không được commit vào Git.

Role chỉ tạo token khi `assistant-secret` chưa có `GITEA_TOKEN`; các lần chạy tiếp theo giữ nguyên token. Nếu secret bị xoá trong khi service account còn tồn tại, playbook sẽ dừng để tránh tạo token mồ côi. Rotation cần thực hiện tường minh: thu hồi token cũ tại Gitea, xoá key `GITEA_TOKEN` khỏi `assistant-secret`, rồi chạy lại playbook và kiểm tra rollout Backend cùng Code-index worker.


## Chạy

```bash
# Từ thư mục NITS/
cd platform/ansible

# Cài toàn bộ (gỡ k3s cũ + cài lại)
ansible-playbook -i inventory/hosts.yml site.yml \
  -e @../../config/ansible/group_vars/all.yml -K

# Chỉ gỡ k3s
ansible-playbook -i inventory/hosts.yml uninstall.yml \
  -e @../../config/ansible/group_vars/all.yml -K
```

> `-K` để nhập sudo password khi cần.

## Sau khi chạy

ArgoCD sẽ tự động sync tất cả apps từ `platform/argocd/applicationset.yaml`.

| Thông tin  | Giá trị                         |
|------------|---------------------------------|
| ArgoCD UI  | `https://localhost:<NodePort>`  |
| Username   | `admin`                         |
| Password   | `nits@2026`                     |
