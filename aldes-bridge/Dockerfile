# Stage 1 : build du frontend React depuis le repo principal
FROM node:20-alpine AS web
ARG CACHEBUST=12
RUN echo "Cache bust: $CACHEBUST" && date
RUN apk add --no-cache git
RUN git clone --depth 1 --branch feature/device-profiles https://github.com/saniho/aldes-bridge.git /src
WORKDIR /src/web
RUN npm ci --no-audit --no-fund && npm run build

# Stage 2 : runtime python
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV ALDES_WEB_DIR=/app/dist

RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

COPY --from=web /src/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY --from=web /src/server/ ./server/
COPY --from=web /src/profiles/ ./profiles/
COPY --from=web /src/web/dist ./dist

RUN mkdir -p /config/aldes

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 18883 8080

ENV ALDES_CONFIG_FILE=/config/aldes/config.json
ENV ALDES_TELEMETRY_FILE=/config/aldes/telemetry.json
ENV ALDES_HISTORY_FILE=/config/aldes/history.db
ENV ALDES_PROFILE_FILE=/config/aldes/profile.json
ENV ALDES_CONSIGNE_FILE=/config/aldes/consigne.json

ENTRYPOINT ["/run.sh"]
