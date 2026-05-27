FROM alpine:latest

ARG PB_VERSION=0.22.12

RUN apk add --no-cache ca-certificates wget unzip
WORKDIR /pb

RUN wget -q https://github.com/pocketbase/pocketbase/releases/download/v/pocketbase__linux_amd64.zip \
    && unzip pocketbase__linux_amd64.zip \
    && rm pocketbase__linux_amd64.zip

# Copy your local PocketBase data (optional, but we'll include for initial seed)
COPY pb_data/ /pb/pb_data/

COPY pb_migrations/ /pb/pb_migrations/

EXPOSE 8090

CMD ["./pocketbase", "serve", "--http=0.0.0.0:8090"]
