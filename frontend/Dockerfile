FROM node:22-alpine
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /app

COPY frontend/package.json frontend/package-lock.json* ./
RUN npm install --no-audit --progress=false --legacy-peer-deps

COPY frontend ./

# build prod bundle
RUN npm run build

# expose and set PORT, keep comments on their own lines
ENV PORT=3000
EXPOSE 3000

# run Next on 0.0.0.0 using $PORT
CMD ["sh","-lc","npm run start"]
