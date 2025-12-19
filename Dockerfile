# ARB Translator Gen Z - Docker Image
FROM dart:3.0-sdk AS build

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./

# Get dependencies
RUN dart pub get

# Copy source code
COPY . .

# Build the application
RUN dart pub get --offline
RUN dart compile exe bin/arb_translator.dart -o bin/arb_translator

# Create minimal runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash arbuser

# Set working directory
WORKDIR /home/arbuser

# Copy compiled binary
COPY --from=build /app/bin/arb_translator /usr/local/bin/arb_translator

# Copy web assets
COPY --from=build /app/web /home/arbuser/web

# Change ownership
RUN chown -R arbuser:arbuser /home/arbuser

# Switch to non-root user
USER arbuser

# Expose ports for web GUI and collaboration
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD arb_translator --help > /dev/null || exit 1

# Default command
ENTRYPOINT ["arb_translator"]
CMD ["--help"]
