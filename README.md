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

Hệ thống bao gồm 4 khối (Containers) chạy song song:
- **`postgres`**: Cơ sở dữ liệu quan hệ, nơi lưu trữ tài khoản người dùng, bình luận, cài đặt hệ thống và cấu hình SSO.
- **`gitea`**: Ứng dụng lõi (Web UI & Git Server). Sử dụng Image tự build tại chỗ `ghcr.io/nguyentukien/platform-service:latest` để giữ lại các tùy biến giao diện.
- **`gitea_runner`**: Máy chủ thực thi các Job CI/CD tự động. 
- **`cloudflared`**: Daemon kết nối với Cloudflare để cấp phát tên miền `git.nits.io.vn` và mã hóa luồng dữ liệu.

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
Mở file `.env` và cấu hình ít nhất các thông số sau:
- `DB_PASS`: Mật khẩu cho Database.
- `CLOUDFLARE_TUNNEL_TOKEN`: Token của Cloudflare Tunnel.

### Bước 3: Khởi chạy hệ thống
Chạy lệnh sau để Docker tự động Build Image giao diện mới nhất và khởi động toàn bộ dịch vụ:
```bash
docker compose up --build -d
```
Chờ khoảng 5-10 giây, bạn có thể truy cập vào tên miền của bạn để sử dụng GitPTIT.

### Bước 4: Đăng ký Runner (Để chạy CI/CD)
Để các Workflow (như file `.gitea/workflows/ci.yaml`) có thể hoạt động:
1. Đăng nhập vào Gitea bằng tài khoản Admin.
2. Vào **Site Administration** -> **Actions** -> **Runners** -> **Create new Runner**.
3. Copy đoạn **Registration Token**.
4. Mở file `.env` lên, dán token đó vào biến `GITEA_RUNNER_TOKEN`.
5. Chạy lại lệnh `docker compose up -d gitea_runner`.

---

## 💾 Hướng dẫn Sao lưu (Backup) & Phục hồi (Restore)

Hệ thống được thiết kế để dễ dàng chuyển nhà. Dữ liệu quý giá nhất nằm ở 2 Docker Volumes: `postgres_data` và `gitea_data`.

### 1. Cách Sao lưu (Backup)
Tạo thư mục chứa bản sao lưu:
```bash
mkdir -p postgres/backups gitea/backups
```
Thực hiện Backup Database ra file `.sql`:
```bash
docker exec postgres bash -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > postgres/backups/database_backup_$(date +%Y-%m-%d).sql
```
Thực hiện Backup Source Code (các Repository) ra file nén `.tar.gz`:
```bash
docker run --rm -v git-platform_gitea_data:/volume -v $(pwd)/gitea/backups:/backup alpine tar -czf /backup/gitea_data_backup_$(date +%Y-%m-%d).tar.gz -C /volume .
```

### 2. Cách Phục hồi (Restore)
Nếu server bị sập hoặc bạn muốn dời sang máy chủ mới, hãy làm đúng thứ tự sau:

```bash
# 1. Dựng lại hệ thống rỗng (để Docker tạo 2 Volume trống)
docker compose up -d

# 2. Chờ 10 giây, sau đó bơm lại dữ liệu vào Database
cat postgres/backups/database_backup_*.sql | docker exec -i postgres psql -U gitea -d gitea

# 3. Dừng Gitea tạm thời để tránh xung đột file
docker stop gitea

# 4. Giải nén Source code đè vào Volume
docker run --rm -v git-platform_gitea_data:/volume -v $(pwd)/gitea/backups:/backup alpine tar -xzf /backup/gitea_data_backup_*.tar.gz -C /volume

# 5. Khởi động lại Gitea
docker start gitea
```

Toàn bộ hệ thống, mã nguồn, cấu hình SSO và tài khoản của bạn sẽ trở lại y hệt như cũ!
