FROM docker.gitea.com/gitea:latest

USER root

# Create our custom folder outside the /data volume
RUN mkdir -p /app/gitea/custom \
    && ln -s /data/gitea/conf /app/gitea/custom/conf

# Copy our branded templates and assets
COPY ./custom/public /app/gitea/custom/public
COPY ./custom/templates /app/gitea/custom/templates

RUN chown -R 1000:1000 /app/gitea/custom

# Tell Gitea to use this new custom folder
ENV GITEA_CUSTOM=/app/gitea/custom

# Gitea's s6-overlay requires running as root initially to set up services, 
# it will automatically drop privileges to the git user.