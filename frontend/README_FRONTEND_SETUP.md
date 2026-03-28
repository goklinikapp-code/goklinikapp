# GoKlinik Frontend Setup

## Stack
- React 18 + Vite + TypeScript
- Tailwind CSS v3
- React Router v6
- TanStack Query v5
- Axios + JWT interceptors
- Zustand
- React Hook Form + Zod
- Recharts
- date-fns
- Lucide React
- react-hot-toast

## Project Structure
- `src/api`: API services
- `src/components`: reusable UI/design system
- `src/layouts`: `AppLayout` and `AuthLayout`
- `src/pages`: route pages
- `src/hooks`: custom hooks
- `src/stores`: Zustand stores
- `src/types`: shared TypeScript types
- `src/utils`: format/helpers

## Environment Variables
Create `.env` from `.env.example`:

```bash
cp .env.example .env
```

Required variable:

```env
VITE_API_URL=http://localhost:8000/api
```

## Local Run (without Docker)

```bash
npm install
npm run dev
```

Frontend: `http://localhost:5173`

## Docker Run

Build and start:

```bash
docker compose up --build
```

Stop:

```bash
docker compose down
```

Frontend in Docker: `http://localhost:5173`

## Build Validation

```bash
npm run build
```

## Auth and Routing
- Public route: `/login`
- Protected routes:
  - `/dashboard`
  - `/patients`
  - `/patients/:id`
  - `/schedule`
  - `/reports`
  - `/team`
  - `/automations`
  - `/settings`

`PrivateRoute` redirects to `/login` if token is missing.

## Branding / White Label
- Branding is loaded by `useTenantStore.loadTenantBranding()`.
- CSS variables are applied at runtime:
  - `--gk-primary`
  - `--gk-secondary`
  - `--gk-accent`

## Notes
- API services have fallback mocks in case endpoints are unavailable.
- Axios interceptor injects `Bearer <token>` and logs out automatically on `401`.
