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
    ├── kubeseal/         # Sealed Secrets controller + CLI
    ├── cnpg/             # CloudNative PG operator
    └── argocd/           # ArgoCD + password + ApplicationSet
```

## Trước khi chạy

Điền các biến bí mật vào `group_vars/all.yml`:

```yaml
ghcr_username: "your-github-username"
ghcr_token: "ghp_xxxxxxxxxxxx"       # GitHub PAT với quyền read:packages
ghcr_email: "your@email.com"
```

## Chạy

```bash
cd ansible/

# Cài toàn bộ (gỡ k3s cũ rồi cài lại)
ansible-playbook -i inventory/hosts.yml site.yml -K

# Chỉ gỡ k3s
ansible-playbook -i inventory/hosts.yml uninstall.yml -K
```

> `-K` để nhập sudo password khi cần.

## Sau khi chạy

ArgoCD sẽ tự động sync tất cả apps từ `platform/argocd/applicationset.yaml`.

| Thông tin  | Giá trị                         |
|------------|---------------------------------|
| ArgoCD UI  | `https://localhost:<NodePort>`  |
| Username   | `admin`                         |
| Password   | `nits@2026`                     |
