# Airflow image for the olist pipeline.
#
# dbt + the CSV loader live in their OWN virtualenv (/opt/pipeline-venv) so their
# dependencies never clash with Airflow's own. The DAG calls the venv binaries
# directly: /opt/pipeline-venv/bin/python and /opt/pipeline-venv/bin/dbt.
FROM apache/airflow:2.10.5-python3.11

# Create the isolated pipeline venv (root makes it, then hands it to airflow).
USER root
RUN python -m venv /opt/pipeline-venv \
    && chown -R airflow: /opt/pipeline-venv
USER airflow

COPY requirements.txt /tmp/requirements.txt
RUN /opt/pipeline-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/pipeline-venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt
