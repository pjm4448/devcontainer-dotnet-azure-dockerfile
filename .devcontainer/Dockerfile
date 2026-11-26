# Development image for this workspace. devcontainer.json builds this file first,
# then installs the .NET and Azure CLI Features on top of the result.
FROM mcr.microsoft.com/devcontainers/base:ubuntu24.04

# 1. OS packages with no Dev Container Feature. This layer changes rarely, so it
#    comes first and stays cached when later lines change.
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        dos2unix \
        shellcheck \
        sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Extra root certificates, such as a corporate proxy CA. Any *.crt file in
#    .devcontainer/certs/ is trusted by the OS store. The folder may hold no
#    certificates; README.md is never added to the store.
COPY certs/ /tmp/extra-ca-certs/
RUN find /tmp/extra-ca-certs -maxdepth 1 -type f -name '*.crt' \
        -exec cp {} /usr/local/share/ca-certificates/ \; \
    && update-ca-certificates \
    && rm -rf /tmp/extra-ca-certs

# Point Python (Azure CLI) and Node.js (VS Code extensions) at the OS bundle,
# which also includes any extra certificates added above.
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# 3. Build argument -> environment variable. devcontainer.json can pass a new
#    value in build.args; the API reads HELLO_GREETING at runtime.
ARG IMAGE_GREETING="Hello from a Dockerfile-built dev container!"
ENV HELLO_GREETING=${IMAGE_GREETING}

# 4. Configuration files baked into the image. Paths are relative to the build
#    context (the .devcontainer folder), not to the repository root.
COPY config/learning.conf /etc/devcontainer-learning/learning.conf
