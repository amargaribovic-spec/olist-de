# Build context is the repo root (so requirements.txt is reachable).
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code, SQL and CSVs are bind-mounted by docker-compose at runtime.
CMD ["python", "load/load_raw.py"]
