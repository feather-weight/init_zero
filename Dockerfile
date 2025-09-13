FROM node:22-alpine AS deps
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --no-audit --progress=false --legacy-peer-deps || npm install --no-audit --progress=false --legacy-peer-deps

FROM node:22-alpine AS builder
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY frontend ./
RUN npm run build

FROM node:22-alpine AS runner
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.js ./next.config.js
EXPOSE 3000
CMD ["npx", "next", "start", "-p", "3000"]
