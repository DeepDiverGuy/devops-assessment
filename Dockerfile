# ---- build stage: install dependencies ----
FROM python:3.12.8-alpine3.21 AS builder
WORKDIR /build
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- final stage: minimal runtime ----
FROM python:3.12.8-alpine3.21
RUN apk upgrade --no-cache
ARG APP_VERSION=1.0.0
ARG VCS_REF=unknown
LABEL org.opencontainers.image.title="devops-task" \
      org.opencontainers.image.description="Small FastAPI service for the DevOps assessment" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/DeepDiverGuy/devops-assessment"

RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app -H app
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/ ./app/

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_VERSION=${APP_VERSION} \
    PORT=8080

USER 10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:'+os.getenv('PORT','8080')+'/health', timeout=2)"

CMD ["python", "-m", "app.main"]
