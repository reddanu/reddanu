FROM golang:1.24-bookworm AS go-builder

ENV GOOS=linux
ENV GOARCH=amd64
ARG VERSION="1.0"
ARG DEBIAN_FRONTEND=noninteractive
ENV SSL_CERT_DIR=/etc/ssl/certs
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
# Create appuser
ENV USER=appuser
ENV UID=10001
RUN apt-get update
RUN apt-get install -y libssl-dev libsasl2-dev wget --fix-missing

# Download and execute the update-certs.sh script
RUN wget -q -O - https://artifactory.chrobinson.com/artifactory/automated-software-storage/ca-certificates/update-certs.sh | sh
RUN update-ca-certificates
# See https://stackoverflow.com/a/55757473/12429735RUN
RUN adduser \
--disabled-password \
--gecos "" \
--shell "/sbin/nologin" \
--uid "${UID}" \
"${USER}"

WORKDIR /app

COPY . ./
RUN ls .

# Build binary
RUN go build -ldflags="-s -w" -o ./main ./main.go

FROM debian:bookworm-slim AS runner
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y libssl-dev libsasl2-dev wget

# Download and execute the update-certs.sh script
RUN wget -q -O - https://artifactory.chrobinson.com/artifactory/automated-software-storage/ca-certificates/update-certs.sh | sh

# Add CHR CA3 label
LABEL com.chrobinson.initiative="trusted-CA3"
LABEL com.chrobinson.certificates="chr-ca-certificates"

# Import the user and group files from the builder.
COPY --from=go-builder /etc/passwd /etc/passwd
COPY --from=go-builder /etc/group /etc/group

# Copy static executable.
COPY --from=go-builder --chown=appuser:appuser /app/main /bin/main

# Use an unprivileged user.
USER appuser:appuser

EXPOSE 8080

ENTRYPOINT [ "/bin/main" ]