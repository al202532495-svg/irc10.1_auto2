FROM python:3.12-slim

WORKDIR /app

# Primero las dependencias: Docker reutiliza esta capa si requirements.txt no cambia
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# No ejecutar como root
RUN useradd --create-home appuser
USER appuser

EXPOSE 5000
# gunicorn es un servidor de produccion; "app:app" = archivo app.py, objeto app
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
