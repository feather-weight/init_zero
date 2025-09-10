# Frontend (Next.js)
FROM node:22-alpine

ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

# Install deps
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm install --no-audit --progress=false --legacy-peer-deps

# App sources + build
COPY frontend ./
RUN npm run build

# No hard-coded port here; compose sets PORT and we pass it to next via command
EXPOSE 3000
