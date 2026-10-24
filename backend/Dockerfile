FROM python:3.12-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .
RUN addgroup --system --gid 10001 app \
    && adduser --system --uid 10001 --ingroup app --home /app app \
    && mkdir -p /app/media /app/staticfiles /var/backups/dokon \
    && chown -R app:app /app /var/backups/dokon
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
USER 10001:10001
EXPOSE 8000
CMD ["gunicorn","config.wsgi:application","--bind","0.0.0.0:8000","--workers","3","--access-logfile","-","--error-logfile","-"]
