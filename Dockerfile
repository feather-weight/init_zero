FROM node:22-alpine

# Disable Next.js telemetry
ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

# Copy package definitions
COPY frontend/package.json frontend/package-lock.json* ./

# Install dependencies (try npm ci first, fallback to install with legacy peer deps)
RUN (npm ci --no-audit --progress=false) || (npm install --no-audit --progress=false --legacy-peer-deps)

# Copy the rest of the frontend source
COPY frontend ./

# Default port inside container; can be overridden by PORT env
ARG FE_PORT=3000
ENV PORT=${FE_PORT}

# Build production bundle
RUN npm run build

EXPOSE 3000

# Start Next.js with host binding; use shell form for env expansion
CMD sh -lc 'HOST=0.0.0.0 PORT="${PORT:-3000}" npm run start -- -H 0.0.0.0 -p "${PORT:-3000}"'
