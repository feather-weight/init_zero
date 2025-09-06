# Step 2(c): Frontend ↔ Backend Wiring (SSR)

- Homepage calls `${NEXT_PUBLIC_BACKEND_URL}/health` on the server.
- Displays backend status badge so you can confirm cross-service connectivity at a glance.
- All ports/URLs pulled from `.env`.

