# Optional: use from the existing repository root (backend/ and website/ siblings).
# Keeps the backend at /app, preserving its existing /app/media location.
FROM python:3.12-slim
WORKDIR /app
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ /app/
COPY website/ /website/
CMD ["sh", "-c", "python manage.py migrate && gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 2 --access-logfile -"]
