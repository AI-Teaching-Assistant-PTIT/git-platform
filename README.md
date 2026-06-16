# Git Platform Service

`platform-service` là bộ cấu hình triển khai nhanh một nền tảng Git self-host phục vụ bài toán project-based learning, CI/CD và autograding. Hệ thống hiện sử dụng Docker Compose để chạy các thành phần chính gồm Gitea, Jenkins, PostgreSQL và Cloudflare Tunnel.

Mục tiêu của repository là tạo một môi trường Git nội bộ, nơi sinh viên hoặc nhóm sinh viên có thể lưu mã nguồn project, còn hệ thống có thể tự động chạy pipeline kiểm thử, build, chấm bài hoặc phản hồi bằng AI thông qua Jenkins.

## 1. Mục tiêu hệ thống

Hệ thống hướng tới các nhu cầu chính:

* Self-host Git repository cho lớp học, môn học hoặc nhóm sinh viên.
* Quản lý source code, pull request, issue và lịch sử commit.
* Tích hợp CI/CD để kiểm thử hoặc chấm bài tự động.
* Chuẩn bị nền tảng cho AI autograding, nơi pipeline có thể gọi service chấm bài bằng AI.
* Public dịch vụ qua Cloudflare Tunnel mà không cần mở trực tiếp port server ra Internet.
* Triển khai nhanh bằng Docker Compose cho môi trường demo hoặc lab nội bộ.

## 2. Kiến trúc tổng quan

```text
                  Internet
                     |
                     v
          +----------------------+
          |  Cloudflare Tunnel   |
          |     cloudflared      |
          +----------+-----------+
                     |
          +----------+-----------+
          |   Docker Network     |
          |   platform_net       |
          +----+------------+----+
               |            |
               v            v
        +---------+    +-----------+
        |  Gitea  |    |  Jenkins  |
        |  :3000  |    |   :8080   |
        +----+----+    +-----+-----+
             |               |
             v               v
      +-------------+   Docker daemon
      | PostgreSQL  |   via docker.sock
      |    :5432    |
      +-------------+
```

## 3. Thành phần chính

| Thành phần               | Vai trò                                                                             |
| ------------------------ | ----------------------------------------------------------------------------------- |
| PostgreSQL               | Database lưu dữ liệu của Gitea                                                      |
| Gitea                    | Git server self-host, quản lý repository, issue, pull request                       |
| Jenkins                  | CI/CD server, chạy pipeline build/test/autograding                                  |
| Cloudflare Tunnel        | Public Gitea/Jenkins ra ngoài thông qua Cloudflare                                  |
| Docker Compose           | Điều phối nhiều container trong môi trường demo/lab                                 |
| Docker CLI trong Jenkins | Cho phép Jenkins chạy `docker build`, `docker run`, `docker compose` trong pipeline |

## 4. Luồng hoạt động dự kiến

### 4.1. Luồng sử dụng Git

```text
Sinh viên / Giảng viên
        |
        v
Truy cập Gitea qua domain
        |
        v
Tạo repo / clone repo / push code / tạo pull request
        |
        v
Gitea lưu source code và metadata vào PostgreSQL
```

Gitea đóng vai trò là Git server nội bộ. Với mô hình project-based learning, mỗi lớp học hoặc môn học có thể được tổ chức thành một organization, trong đó mỗi nhóm sinh viên có một repository riêng.

Ví dụ:

```text
big-data-course/
├── group-01-project
├── group-02-project
├── group-03-project
└── group-04-project
```

### 4.2. Luồng CI/CD và autograding

```text
Sinh viên push code / tạo pull request
        |
        v
Gitea Webhook kích hoạt Jenkins Job
        |
        v
Jenkins clone repository
        |
        v
Jenkins chạy test/build/checkstyle/static analysis
        |
        v
Jenkins gọi AI Grader Service, nếu có
        |
        v
AI Grader sinh nhận xét / điểm / gợi ý
        |
        v
Kết quả được ghi lại vào pull request, dashboard hoặc database hệ thống
```

Ở giai đoạn hiện tại, repository mới cung cấp hạ tầng nền để chạy Gitea và Jenkins. Phần webhook, Jenkins job, AI grader và dashboard có thể được bổ sung ở các repository/service tiếp theo.

### 4.3. Luồng public service qua Cloudflare Tunnel

```text
User truy cập domain
        |
        v
Cloudflare
        |
        v
Cloudflare Tunnel
        |
        v
Container cloudflared
        |
        v
Route nội bộ tới Gitea hoặc Jenkins
```

Ví dụ cấu hình public hostname trên Cloudflare Zero Trust:

```text
git.example.com      -> http://gitea:3000
jenkins.example.com  -> http://jenkins:8080
```

Trong Docker Compose, `cloudflared` nằm cùng network `platform_net` với Gitea và Jenkins, nên có thể forward request tới service name nội bộ như `gitea:3000` hoặc `jenkins:8080`.

## 5. Tech Stack

| Nhóm                     | Công nghệ                                    |
| ------------------------ | -------------------------------------------- |
| Git hosting              | Gitea                                        |
| CI/CD                    | Jenkins                                      |
| Database                 | PostgreSQL 15 Alpine                         |
| Network exposure         | Cloudflare Tunnel / cloudflared              |
| Container runtime        | Docker                                       |
| Orchestration local/demo | Docker Compose                               |
| Jenkins image            | `jenkins/jenkins:lts` custom thêm Docker CLI |
| Gitea image              | `docker.gitea.com/gitea:latest`              |
| Cloudflare image         | `cloudflare/cloudflared:latest`              |

## 6. Cấu trúc repository

```text
platform-service/
├── docker-compose.yaml
├── .env.example
├── .gitignore
├── README.md
└── jenkins/
    └── Dockerfile
```

### `docker-compose.yaml`

File chính để chạy toàn bộ stack. Các service hiện có:

* `postgres`
* `gitea`
* `jenkins`
* `cloudflared`

Các named volume:

* `postgres_data`
* `gitea_data`
* `jenkins_home`

Docker network:

* `platform_net`

### `.env.example`

File mẫu chứa các biến môi trường cho database, Gitea, Jenkins và Cloudflare Tunnel.

### `jenkins/Dockerfile`

Custom Jenkins image từ `jenkins/jenkins:lts`, cài thêm:

* `docker-ce-cli`
* `docker-compose-plugin`

Nhờ đó Jenkins có thể gọi Docker daemon của host thông qua `/var/run/docker.sock`.

## 7. Cài đặt và chạy thử

### 7.1. Yêu cầu

Máy host cần có:

* Docker
* Docker Compose plugin
* Tài khoản Cloudflare nếu muốn public qua Tunnel
* Domain đã trỏ về Cloudflare nếu dùng hostname public

### 7.2. Chuẩn bị biến môi trường

Copy file env mẫu:

```bash
cp .env.example .env
```

Cập nhật lại các giá trị trong `.env`:

```env
# Database
DB_USER=gitea
DB_PASS=gitea_secret_password
DB_NAME=gitea

# Gitea
GITEA_DOMAIN=git.example.com
GITEA__APP_NAME=Git Platform
GITEA__database__DB_TYPE=postgres
GITEA__database__HOST=postgres:5432
GITEA__database__NAME=${DB_NAME}
GITEA__database__USER=${DB_USER}
GITEA__database__PASSWD=${DB_PASS}

USER_UID=1000
USER_GID=1000

GITEA__server__DOMAIN=${GITEA_DOMAIN}
GITEA__server__ROOT_URL=https://${GITEA_DOMAIN}/
GITEA__server__SSH_DOMAIN=${GITEA_DOMAIN}
GITEA__server__SSH_PORT=2222
GITEA__server__DISABLE_SSH=false
GITEA__server__LFS_START_SERVER=true
GITEA__service__DISABLE_REGISTRATION=true

# Jenkins
JENKINS_OPTS=--prefix=/

# Cloudflare Tunnel
CLOUDFLARE_TUNNEL_TOKEN=your_cloudflare_tunnel_token_here
```

### 7.3. Khởi chạy stack

```bash
docker compose up -d --build
```

Kiểm tra trạng thái container:

```bash
docker compose ps
```

Xem log:

```bash
docker compose logs -f
```

Xem log từng service:

```bash
docker compose logs -f gitea
docker compose logs -f jenkins
docker compose logs -f cloudflared
docker compose logs -f postgres
```

## 8. Truy cập dịch vụ

Nếu chạy local:

```text
Gitea:   http://localhost:3000
Jenkins: http://localhost:8080
```

Nếu dùng Cloudflare Tunnel:

```text
Gitea:   https://git.example.com
Jenkins: https://jenkins.example.com
```

Lấy mật khẩu Jenkins lần đầu:

```bash
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Sau đó truy cập Jenkins UI và hoàn tất bước setup ban đầu.

## 9. Gợi ý cấu hình webhook giữa Gitea và Jenkins

Mục tiêu là khi sinh viên push code hoặc tạo pull request, Gitea sẽ gọi Jenkins để chạy pipeline.

Luồng dự kiến:

```text
Gitea Repository
    -> Settings
    -> Webhooks
    -> Add Webhook
    -> Jenkins endpoint
```

Ví dụ endpoint Jenkins:

```text
https://jenkins.example.com/gitea-webhook/post
```

Tùy plugin Jenkins được dùng, endpoint thực tế có thể khác nhau.

## 10. Định hướng AI Autograding

Repository hiện tại mới là phần hạ tầng Git/CI nền tảng. Để hoàn thiện bài toán AI autograding, có thể bổ sung thêm các service sau:

```text
platform-service/
├── Gitea
├── Jenkins
├── PostgreSQL
├── Cloudflare Tunnel
└── Future services:
    ├── AI Grader Service
    ├── Rubric Service
    ├── CourseOps Backend
    ├── Student Progress Service
    └── Dashboard Service
```

Luồng AI chấm bài đề xuất:

```text
1. Sinh viên push code lên Gitea.
2. Gitea trigger Jenkins job.
3. Jenkins clone repository và chạy test.
4. Jenkins gửi metadata sang AI Grader Service:
   - repo URL
   - commit SHA
   - branch
   - assignment ID
   - course ID
   - test result
5. AI Grader phân tích code, rubric và kết quả test.
6. AI Grader trả về:
   - nhận xét kỹ thuật
   - lỗi chính
   - gợi ý sửa theo hướng Socratic
   - điểm tạm thời
7. Jenkins hoặc backend ghi feedback về Gitea pull request.
8. Hệ thống lưu progress vào database để giảng viên theo dõi.
```

## 11. Lưu ý bảo mật

### 11.1. Docker socket trong Jenkins

Trong `docker-compose.yaml`, Jenkins đang mount Docker socket:

```yaml
- /var/run/docker.sock:/var/run/docker.sock
```

Cách này giúp Jenkins chạy được Docker command, nhưng cũng cho Jenkins quyền rất mạnh trên Docker host.

Phù hợp cho:

* demo
* lab nội bộ
* môi trường thử nghiệm

Không nên dùng trực tiếp cho production nếu chưa có kiểm soát bảo mật.

Với production, nên cân nhắc:

* Jenkins agent riêng
* Docker-in-Docker cô lập
* BuildKit
* Kaniko
* Kubernetes executor
* GitLab Runner hoặc Jenkins agent chạy trong namespace riêng

### 11.2. Jenkins không nên public trần

Nếu public Jenkins qua Cloudflare Tunnel, nên bật thêm:

* Cloudflare Access
* SSO
* allowlist email domain trường
* MFA
* phân quyền Jenkins user rõ ràng

### 11.3. Không commit secret

Không commit file `.env` thật lên repository.

Chỉ commit:

```text
.env.example
```

Các secret cần được giữ riêng:

* database password
* Cloudflare Tunnel token
* Jenkins admin password
* API key LLM
* token gọi AI Grader Service

## 12. Roadmap

### Giai đoạn 1: Demo hạ tầng

* [x] Chạy Gitea bằng Docker Compose
* [x] Chạy PostgreSQL cho Gitea
* [x] Chạy Jenkins
* [x] Custom Jenkins image có Docker CLI
* [x] Thêm Cloudflare Tunnel
* [ ] Hoàn thiện README
* [ ] Thêm hướng dẫn cấu hình Cloudflare public hostname

### Giai đoạn 2: CI/CD cơ bản

* [ ] Cấu hình Jenkins plugin cho Gitea webhook
* [ ] Tạo Jenkins job mẫu cho Java project
* [ ] Tạo Jenkins job mẫu cho Python project
* [ ] Tạo webhook tự động từ Gitea sang Jenkins
* [ ] Ghi kết quả build/test về pull request

### Giai đoạn 3: AI Autograding

* [ ] Xây dựng AI Grader Service
* [ ] Thiết kế rubric format
* [ ] Tích hợp LLM API
* [ ] Tích hợp hidden test
* [ ] Sinh feedback tự động cho sinh viên
* [ ] Lưu progress theo nhóm/sinh viên

### Giai đoạn 4: Production

* [ ] Tách runner khỏi Jenkins controller
* [ ] Thêm backup PostgreSQL/Gitea/Jenkins
* [ ] Thêm monitoring/logging
* [ ] Thêm rate limit và access control
* [ ] Cân nhắc migrate sang Kubernetes nếu tải tăng

## 13. Nguồn tham khảo

* Gitea Documentation — Installation with Docker
* Gitea Documentation — Configuration Cheat Sheet
* Jenkins Documentation — Installing Jenkins with Docker
* Jenkins Documentation — Pipeline
* Docker Documentation — Docker Compose
* Docker Documentation — Volumes
* Cloudflare Documentation — Cloudflare Tunnel setup
* Cloudflare Documentation — cloudflared tunnel run parameters
