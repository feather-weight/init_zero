# Step 1(b): Scaffold Backend Healthcheck

This step adds a minimal **FastAPI** backend with a `/health` route, permissive CORS (dev), a pinned `requirements.txt`, and a small Python 3.12-slim Dockerfile. Docker Compose is extended to include the backend alongside Mongo.

- Outcome: `GET http://localhost:8000/health` returns `{"status":"ok",...}`.
- This aligns with the baseline scaffold in the 0→20 plan and stages the async, Mongo-ready scanner services for Infura/Tatum/Blockchair integrations in later sub-steps.

