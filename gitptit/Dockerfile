# Pin theo version đang chạy: template custom override base/head_navbar nên phải
# khớp version Gitea, và Gitea không hỗ trợ hạ version database.
FROM docker.gitea.com/gitea:1.27.2

USER root

# tzdata để biến TZ có hiệu lực khi container không mount /etc/localtime (Kubernetes).
# Custom folder nằm ngoài volume /data, chỉ conf được trỏ vào /data để giữ app.ini.
RUN apk add --no-cache tzdata \
    && mkdir -p /app/gitea/custom \
    && ln -s /data/gitea/conf /app/gitea/custom/conf

# Copy our branded templates and assets
COPY ./custom/public /app/gitea/custom/public
COPY ./custom/templates /app/gitea/custom/templates
COPY ./scripts/bootstrap.sh /usr/local/bin/gitptit-bootstrap

RUN chmod 0755 /usr/local/bin/gitptit-bootstrap \
    && chown -R 1000:1000 /app/gitea/custom

# Stable defaults; runtime environment variables can override these values.
ENV GITEA_CUSTOM=/app/gitea/custom \
    TZ=Asia/Ho_Chi_Minh \
    USER_UID=1000 \
    USER_GID=1000 \
    # APP_NAME nằm ngoài mọi section nên environment-to-ini yêu cầu 4 dấu gạch dưới.
    GITEA____APP_NAME=GITPTIT \
    GITEA__server__HTTP_PORT=3000 \
    GITEA__server__LFS_START_SERVER=true \
    GITEA__database__DB_TYPE=postgres \
    GITEA__server__SSH_PORT=2222 \
    GITEA__server__DISABLE_SSH=false \
    GITEA__service__DISABLE_REGISTRATION=false \
    GITEA__service__ALLOW_ONLY_EXTERNAL_REGISTRATION=true \
    GITEA__server__LANDING_PAGE=explore \
    GITEA__actions__ENABLED=true \
    GITEA__oauth2_client__ACCOUNT_LINKING=auto \
    GITEA__oauth2_client__UPDATE_AVATAR=true \
    GITEA__oauth2_client__ENABLE_AUTO_REGISTRATION=true \
    GITEA__oauth2_client__USERNAME=preferred_username \
    GITEA__service__VALID_USERNAME_CHARS=a-zA-Z0-9_-. \
    GITEA__security__INSTALL_LOCK=true

ENTRYPOINT ["/usr/local/bin/gitptit-bootstrap"]

# The wrapper starts the official Gitea entrypoint and bootstraps runtime state.
