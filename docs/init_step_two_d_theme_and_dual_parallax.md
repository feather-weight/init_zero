# Step 2(d): Theme Toggle + Dual Parallax

- Adds a light/dark toggle persisted in localStorage with `prefers-color-scheme` fallback.
- Parallax hero uses CSS variables so the background image swaps by theme:
  - Light → `/parallax-light.jpg`
  - Dark →  `/parallax-dark.png`
- Respects `NEXT_PUBLIC_PARALLAX` in `.env` (1 on, 0 off).
- Accessible: background-attachment relaxes if user prefers reduced motion.

Place your images at:
- `frontend/public/parallax-dark.png`
- `frontend/public/parallax-light.jpg`
