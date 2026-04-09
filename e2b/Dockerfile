# E2B sandbox template: Goose pre-installed, ready to connect to cloud DONNA
#
# Build and push this template with the E2B CLI:
#   e2b template build --name donna-goose
#   e2b template push
#
# The resulting template ID goes into E2B_TEMPLATE_ID env var.

FROM e2bdev/code-interpreter:latest

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (needed to build Goose from source, or swap for a pre-built binary)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

# Clone and build goose-server
# In production, replace with a pre-built release binary download for faster startup
WORKDIR /opt/goose
COPY . .
RUN cargo build --release --bin goose-server 2>&1

# Copy startup script
COPY services/goose/e2b/start.sh /opt/goose/start.sh
RUN chmod +x /opt/goose/start.sh

# Goose HTTP port
EXPOSE 3000

CMD ["/opt/goose/start.sh"]
