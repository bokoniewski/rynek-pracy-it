# Dockerfile
# Obraz bazowy Airflow z Python 3.10
FROM apache/airflow:2.9.0-python3.10
 
# Przełącz na roota żeby zainstalować systemowe zależności
USER root
 
# Instalacja systemowych zależności + Google Chrome
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    wget \
    gnupg \
    unzip \
    xvfb \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
 
USER airflow
 
# setuptools — naprawia pkg_resources (openlineage warning)
RUN pip install --no-cache-dir setuptools
 
# Paczki scraper/loader (zawiera selenium, undetected_chromedriver, webdriver_manager)
COPY requirements/requirements_get_job.txt /tmp/requirements_get_job.txt
RUN pip install --no-cache-dir -r /tmp/requirements_get_job.txt
 
# Paczka transformation
COPY requirements/requirements_dbt.txt /tmp/requirements_dbt.txt
RUN pip install --no-cache-dir -r /tmp/requirements_dbt.txt

# Paczka airflow_prod (zawiera openlineage)
COPY requirements/requirements_orchestration.txt /tmp/requirements_orchestration.txt
RUN pip install --no-cache-dir -r /tmp/requirements_orchestration.txt