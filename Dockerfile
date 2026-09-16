# Stage 1: Build
FROM python:3.13-slim AS builder

WORKDIR /build

COPY app/requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Stage 2: Runtime
FROM python:3.13-slim

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app/main.py .

RUN useradd --create-home appuser

USER appuser

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]