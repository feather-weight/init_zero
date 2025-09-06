FROM node:22-alpine
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json* ./
# Use --legacy-peer-deps to avoid breaking on peer-dep conflicts
RUN npm install --no-audit --progress=false --legacy-peer-deps
COPY frontend ./
ARG FRONTEND_INTERNAL_PORT=3000
ENV FRONTEND_INTERNAL_PORT=${FRONTEND_INTERNAL_PORT}
EXPOSE ${FRONTEND_INTERNAL_PORT}
CMD ["npm","run","start"]
