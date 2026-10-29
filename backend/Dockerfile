
FROM python:3.12-slim

WORKDIR /app

# backup_database uses pg_dump for PostgreSQL; psycopg alone does not supply it.
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["sh", "-c", "python manage.py migrate && exec gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --access-logfile - --error-logfile -"]
