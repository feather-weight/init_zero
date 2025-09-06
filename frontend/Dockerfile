FROM node:22-alpine
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /app

# Install dependencies
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm install --no-audit --progress=false --legacy-peer-deps

COPY frontend ./
# Build the production bundle
RUN npm run build

EXPOSE 3000

# Run the production server on all interfaces; the start script already specifies the port
CMD ["npm", "run", "start"]
