"""Database-free smoke tests for verifying FastAPI application startup in CI."""

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_docs_available():
    """Verify the FastAPI app initializes cleanly and serves Swagger UI at /docs."""
    response = client.get("/docs")

    assert response.status_code == 200
