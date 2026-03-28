# Go Klinik Backend Setup

## 1. Prerequisites
- Python 3.11+
- Poetry 2.x
- Docker + Docker Compose (optional, recommended)
- PostgreSQL access via Supabase

## 2. Go to backend folder
```bash
cd GoKlinik/backend
```

## 3. Create environment file
```bash
cp .env.example .env
```

## 4. Install dependencies with Poetry
```bash
poetry install
```

## 5. Run migrations
```bash
poetry run python manage.py migrate
```

## 6. Seed demo data
```bash
poetry run python manage.py seed_goklinik
```

This creates:
- Tenant: `GoKlinik Demo` (`goklinik-demo`)
- Master user: `admin@goklinik.com` / `GoKlinik2024!`
- 8 specialties
- 3 demo surgeons

## 7. Run local API (Poetry)
```bash
poetry run python manage.py runserver
```

## 8. Run Celery locally
In another terminal:
```bash
cd GoKlinik/backend
poetry run celery -A config worker -l info
```

Optional beat scheduler:
```bash
poetry run celery -A config beat -l info
```

## 9. Run with Docker Compose
```bash
docker compose up --build -d
```

Notes:
- Docker stack also uses Supabase as database (same `DATABASE_URL` from `.env`).
- Redis stays in Docker for Celery broker/backend.

First-time seed inside container:
```bash
docker compose exec web poetry run python manage.py seed_goklinik
```

Create Django superuser inside container:
```bash
docker compose exec web poetry run python manage.py createsuperuser
```

Stop containers:
```bash
docker compose down
```

## 10. API Documentation
- Swagger UI: `http://127.0.0.1:8000/api/docs/`
- OpenAPI Schema: `http://127.0.0.1:8000/api/schema/`

## Main Authentication Endpoints
- `POST /api/auth/register/`
- `POST /api/auth/login/`
- `POST /api/auth/refresh/`
- `POST /api/auth/forgot-password/`
- `POST /api/auth/change-password/`

## Main Patients Endpoints
- `GET /api/patients/`
- `GET /api/patients/{id}/`
- `POST /api/patients/`
- `PUT /api/patients/{id}/`
- `GET /api/patients/{id}/timeline/`

## Public Branding Endpoint
- `GET /api/public/tenants/{slug}/branding/`

## Stage 2 Main Endpoints
- `GET /api/appointments/available-slots/?professional_id=<uuid>&date=YYYY-MM-DD`
- `POST /api/appointments/`
- `GET /api/appointments/`
- `PUT /api/appointments/{id}/status/`
- `DELETE /api/appointments/{id}/`
- `GET /api/post-op/my-journey/`
- `PUT /api/post-op/checklist/{id}/complete/`
- `POST /api/post-op/photos/`
- `GET /api/post-op/photos/{journey_id}/`
- `GET /api/post-op/admin/journeys/`
- `GET /api/chat/rooms/`
- `POST /api/chat/rooms/`
- `GET /api/chat/rooms/{id}/messages/`
- `POST /api/chat/rooms/{id}/messages/`
- `PUT /api/chat/rooms/{id}/read/`
- `GET /api/notifications/`
- `PUT /api/notifications/{id}/read/`
- `POST /api/notifications/register-token/`
- `POST /api/notifications/admin/broadcast/`
- `GET /api/financial/my-transactions/`
- `GET /api/financial/admin/transactions/`
- `POST /api/financial/transactions/`
- `PUT /api/financial/transactions/{id}/mark-paid/`
- `GET /api/financial/admin/dashboard/`
- `GET /api/medical-records/{patient_id}/documents/`
- `POST /api/medical-records/{patient_id}/documents/`
- `GET /api/medical-records/{patient_id}/access-log/`
- `GET /api/admin/dashboard/`

## Run Automated Tests
```bash
poetry run python manage.py test
```
