# GitPTIT - Nền tảng quản lý mã nguồn nội bộ

GitPTIT là một hệ thống quản lý mã nguồn tự lưu trữ (Self-hosted Git Platform) được tùy biến sâu dựa trên Gitea. Hệ thống được thiết kế tối giản, bảo mật, tích hợp sẵn các công cụ CI/CD nội bộ và hệ thống xác thực tập trung, phục vụ riêng cho nhu cầu quản lý dự án, bài tập và mã nguồn.

Hệ thống được đóng gói hoàn toàn bằng Docker Compose, giúp việc triển khai, sao lưu và di chuyển giữa các máy chủ trở nên cực kỳ dễ dàng.

---

## 🚀 Các chức năng nổi bật

1. **Giao diện tùy biến (Branding):** 
   - Hệ thống được tùy chỉnh sâu về giao diện (CSS, Logo, Favicon, Navbar, Footer) mang đậm nhận diện thương hiệu GitPTIT.
   - Quá trình tùy biến được đóng gói trực tiếp vào Dockerfile, cho phép tự động build thành một Image hoàn chỉnh khi triển khai.

2. **Xác thực tập trung (Microsoft SSO):** 
   - Đăng nhập một chạm (Single Sign-On) thông qua Microsoft Entra ID (Azure AD) bằng giao thức OpenID Connect.
   - Tự động tạo tài khoản (Auto Registration) cho người dùng mới khi đăng nhập bằng Microsoft, đồng thời vô hiệu hóa form đăng ký thủ công để chống spam.

3. **Tích hợp sẵn CI/CD (Gitea Actions):** 
   - Không cần sử dụng các hệ thống cồng kềnh như Jenkins. Hệ thống tích hợp sẵn Gitea Runner (tương thích hoàn toàn với cú pháp của GitHub Actions).
   - Hỗ trợ chạy các Pipeline tự động như Build Docker Image, Quét bảo mật bằng Trivy, hay Deploy tự động mỗi khi có code mới được Push.

4. **Bảo mật mạng (Cloudflare Tunnel):** 
   - Hệ thống không cần mở cổng (port) trực tiếp ra ngoài Internet. Traffic được bảo mật và định tuyến thông qua Cloudflare Zero Trust Tunnel.

---

## 🏗 Kiến trúc hệ thống (Docker Compose)

| Service | Image | Vai trò |
|---------|-------|---------|
| `gitptit` | build từ [gitptit/Dockerfile](gitptit/Dockerfile) | Gitea đã tùy biến giao diện + bootstrap SSO. Cổng `3000` (web), `2222` (SSH) |
| `postgres` | `pgvector/pgvector:pg15` | Chứa cả database của GitPTIT (`POSTGRES_DB`) và của webapp (`WEBAPP_DB`) |
| `minio` | `minio/minio` | Object storage cho tài liệu khoá học. Cổng `9000` (S3 API), `9001` (console) |
| `docling` | `docling-serve-cpu` | Chuyển tài liệu (PDF, DOCX…) sang text cho pipeline knowledge |
| `prestart` | `backend:latest` | Chạy migration + seed dữ liệu ban đầu rồi thoát (`restart: "no"`) |
| `backend` | `backend:latest` | API của webapp. Cổng `8000` |
| `knowledge-worker` | `backend:latest` | Worker nền xử lý tài liệu đã upload |
| `frontend` | `frontend:latest` | Web UI. Cổng `80` |
| `cloudflared` | `cloudflare/cloudflared` | Cloudflare Tunnel, chỉ chạy khi có `CLOUDFLARE_TUNNEL_TOKEN` |

Tất cả nằm trên network `platform_net`. Dữ liệu lâu dài ở 4 volume: `gitptit_data`,
`postgres_data`, `minio_data`, `app-docling-cache`.

---

## 🛠 Hướng dẫn Cài đặt & Chạy hệ thống

### Bước 1: Yêu cầu chuẩn bị
- Máy chủ cài sẵn **Docker** và **Docker Compose**.
- Đã Clone repository này về máy.

### Bước 2: Thiết lập biến môi trường
Sao chép file cấu hình mẫu và điền các thông số bảo mật của bạn:
```bash
cp .env.example .env
```
Mở file `.env` và cấu hình ít nhất các nhóm thông số sau:

| Nhóm | Biến | Ghi chú |
|------|------|---------|
| Database | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `GITEA__database__HOST`, `GITEA__database__NAME`, `GITEA__database__USER`, `GITEA__database__PASSWD` | Tài khoản Gitea dùng để kết nối PostgreSQL |
| Tài khoản admin | `GITEA_ADMIN_USERNAME`, `GITEA_ADMIN_PASSWORD`, `GITEA_ADMIN_EMAIL` | Container tự tạo admin trong lần khởi động đầu |
| Microsoft SSO | `SSO_CLIENT_ID`, `SSO_SECRET`, `SSO_DIRECTORY_ID` | Client ID, client secret **value** và Tenant ID trên Entra ID. Để trống cả ba biến nếu chưa dùng SSO |
| Tên miền | `GITEA__server__DOMAIN`, `GITEA__server__ROOT_URL`, `GITEA__server__SSH_DOMAIN` | Dùng cho URL clone và redirect URI của SSO |
| Cloudflare | `CLOUDFLARE_TUNNEL_TOKEN` | Token của Cloudflare Tunnel |

### Bước 3: Khởi chạy hệ thống
Chạy lệnh sau để Docker tự động Build Image giao diện mới nhất và khởi động toàn bộ dịch vụ:
```bash
docker compose up --build -d
```
Chờ khoảng 5-10 giây, bạn có thể truy cập vào tên miền của bạn để sử dụng GitPTIT.

---

## ⚙️ Tự cấu hình khi khởi động (bootstrap)

Image GitPTIT không dùng trang cài đặt qua web (`INSTALL_LOCK = true`). Toàn bộ cấu hình
đến từ biến môi trường: entrypoint `gitptit-bootstrap` ([gitptit/scripts/bootstrap.sh](gitptit/scripts/bootstrap.sh))
chạy trước Gitea và thực hiện tuần tự:

1. Sinh `app.ini` rồi áp mọi biến `GITEA__*` vào file cấu hình.
2. `gitea migrate` để tạo/nâng cấp schema, chờ database sẵn sàng.
3. Tạo tài khoản admin từ `GITEA_ADMIN_USERNAME` / `GITEA_ADMIN_PASSWORD` / `GITEA_ADMIN_EMAIL`.
4. Tạo hoặc cập nhật nguồn đăng nhập Microsoft từ `SSO_CLIENT_ID` / `SSO_SECRET` / `SSO_DIRECTORY_ID`.

Sau đó quyền được giao lại cho entrypoint gốc của Gitea, nên vòng đời container giữ nguyên như image upstream.

### Biến tuỳ chọn

| Biến | Mặc định | Tác dụng |
|------|----------|----------|
| `SSO_AUTH_NAME` | `Microsoft` | Tên nguồn đăng nhập. Không được chứa khoảng trắng vì nó nằm trong redirect URI |
| `GITPTIT_DB_WAIT_TIMEOUT` | `300` | Số giây chờ database trước khi bỏ cuộc |
| `GITPTIT_SSO_ATTEMPTS` | `3` | Số lần thử cấu hình nguồn đăng nhập |

### Redirect URI cần đăng ký trên Microsoft Entra ID

```
<GITEA__server__ROOT_URL>user/oauth2/<SSO_AUTH_NAME>/callback
```

Ví dụ với cấu hình mặc định: `https://git.nits.io.vn/user/oauth2/Microsoft/callback`.
Nếu đổi `SSO_AUTH_NAME` thì phải sửa lại redirect URI trên Entra ID cho khớp.

### Hành vi khi khởi động lại

- Bootstrap chạy ở **mọi** lần khởi động và idempotent: admin đã tồn tại thì bỏ qua
  (không ghi đè mật khẩu đã đổi), nguồn đăng nhập đã tồn tại thì được cập nhật thay vì tạo trùng.
- Rotate client secret chỉ cần sửa `SSO_SECRET` rồi khởi động lại container.
- Bỏ trống cả ba biến `SSO_*` để tắt SSO. Nếu chỉ điền một hoặc hai biến, container
  dừng ngay với thông báo thiếu biến để tránh cấu hình nửa vời.
- Nếu không gọi được discovery URL của Microsoft, bootstrap chỉ ghi cảnh báo và Gitea
  vẫn khởi động — admin vẫn đăng nhập được bằng mật khẩu nội bộ.

> Khi triển khai trên Kubernetes, các giá trị nhạy cảm nằm trong Secret `gitea-<namespace>`
> do Ansible role `runtime_secrets` tạo từ `platform/.env`; xem [ansible/README.md](ansible/README.md).

## 💾 Hướng dẫn Sao lưu (Backup) & Phục hồi (Restore)

Hệ thống được thiết kế để dễ dàng chuyển nhà. Dữ liệu quý giá nhất nằm ở 2 Docker Volumes: `postgres_data` và `gitptit_data`.

> Docker thêm tiền tố tên project vào volume. Project mặc định lấy theo tên thư mục
> chứa `docker-compose.yaml` (ở đây là `platform`), nên volume thật là
> `platform_gitptit_data`. Chạy `docker volume ls` để xác nhận trước khi backup.

### 1. Cách Sao lưu (Backup)
Tạo thư mục chứa bản sao lưu:
```bash
mkdir -p postgres/backups gitptit/backups
```
Thực hiện Backup Database ra file `.sql` (dump cả database GitPTIT và database webapp):
```bash
docker exec postgres bash -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > postgres/backups/gitptit_backup_$(date +%Y-%m-%d).sql
docker exec postgres bash -c 'pg_dump -U "$POSTGRES_USER" "$WEBAPP_DB"' > postgres/backups/assistant_backup_$(date +%Y-%m-%d).sql
```
Thực hiện Backup Source Code (các Repository) ra file nén `.tar.gz`:
```bash
docker run --rm -v platform_gitptit_data:/volume -v $(pwd)/gitptit/backups:/backup alpine tar -czf /backup/gitptit_data_backup_$(date +%Y-%m-%d).tar.gz -C /volume .
```

### 2. Cách Phục hồi (Restore)
Nếu server bị sập hoặc bạn muốn dời sang máy chủ mới, hãy làm đúng thứ tự sau:

```bash
# 1. Dựng lại hệ thống rỗng (để Docker tạo các Volume trống)
docker compose up -d

# 2. Chờ 10 giây, sau đó bơm lại dữ liệu vào Database
cat postgres/backups/gitptit_backup_*.sql | docker exec -i postgres bash -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
cat postgres/backups/assistant_backup_*.sql | docker exec -i postgres bash -c 'psql -U "$POSTGRES_USER" -d "$WEBAPP_DB"'

# 3. Dừng GitPTIT tạm thời để tránh xung đột file
docker stop gitptit

# 4. Giải nén Source code đè vào Volume
docker run --rm -v platform_gitptit_data:/volume -v $(pwd)/gitptit/backups:/backup alpine tar -xzf /backup/gitptit_data_backup_*.tar.gz -C /volume

# 5. Khởi động lại GitPTIT
docker start gitptit
```

Toàn bộ hệ thống, mã nguồn, cấu hình SSO và tài khoản của bạn sẽ trở lại y hệt như cũ!
