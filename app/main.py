import json
import logging

from fastapi import FastAPI, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI()


# Structured JSON logging
logger = logging.getLogger("novapay")
logger.setLevel(logging.INFO)

handler = logging.StreamHandler()
logger.addHandler(handler)


def log_event(level, event, **details):
    log_entry = {
        "level": level,
        "service": "novapay-wallet",
        "event": event,
        **details
    }

    logger.info(json.dumps(log_entry))


# Custom Prometheus metric
wallet_requests = Counter(
    "novapay_wallet_requests_total",
    "Total number of requests to the NovaPay wallet endpoint"
)


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/ready")
def ready():
    return {"status": "ready"}


@app.get("/version")
def version():
    return {"version": "1.0.0"}


@app.get("/wallets/{wallet_id}")
def get_wallet(wallet_id: str):
    wallet_requests.inc()

    log_event(
        "INFO",
        "wallet_retrieved",
        wallet_id=wallet_id
    )

    return {
        "id": wallet_id,
        "balance_kobo": 500000
    }


@app.get("/metrics")
def metrics():
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )