FROM alpine:latest

# Install PocketBase
RUN apk add --no-cache ca-certificates wget unzip
WORKDIR /pb
ARG PB_VERSION=0.22.12
RUN wget -q https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip \
    && unzip pocketbase_${PB_VERSION}_linux_amd64.zip \
    && rm pocketbase_${PB_VERSION}_linux_amd64.zip

# Copy local PocketBase data and migrations into the image
# WARNING: `pb_data/` contains your admin account and secrets.
COPY pb_data/ /pb/pb_data/
COPY pb_migrations/ /pb/pb_migrations/

EXPOSE 8090

# Start PocketBase
CMD ["./pocketbase", "serve", "--http=0.0.0.0:8090"]
