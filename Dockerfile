# =============================================================
# hydro-tests-runner — образ для прогонов автотестов Гидроуклона в CI.
#
# Принцип: все зависимости ЗАШИВАЮТСЯ в образ с зафиксированными версиями
# (pyproject.toml / poetry.lock). Пайп только делает docker pull из
# Nexus Docker Registry и гоняет pytest — это ускоряет прогон.
# Актуальность версий библиотек НЕ является целью; версии меняем только
# осознанно.
#
# Пересборка: при изменении poetry.lock / pyproject.toml или вручную.
# Тег образа = версия из pyproject.toml + короткий hash poetry.lock
# (формируется в job-е сборки; .gitlab-ci.yml появится после согласования
# триггеров с разработчиками).
#
# sdku-test-tools попадает в образ как wheel из Nexus private PyPI
# (зависимость в pyproject.toml с фиксированной версией).
# =============================================================

# Базовый образ — через прокси корпоративного Nexus (не из интернета).
ARG BASE_IMAGE=python:3.12-slim
FROM ${BASE_IMAGE}

# Параметры сборки из GitLab CI variables: адреса Nexus.
# Значения не зашиваются в репозиторий.
ARG NEXUS_PYPI_URL
ARG NEXUS_PYPI_USERNAME
ARG NEXUS_PYPI_PASSWORD
ARG POETRY_VERSION=2.1.3

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    PIP_INDEX_URL=${NEXUS_PYPI_URL} \
    PIP_TRUSTED_HOST=nexus

WORKDIR /app

# Poetry — только как инструмент установки зависимостей по poetry.lock.
RUN pip install --no-cache-dir "poetry==${POETRY_VERSION}"

# Сначала только манифесты — слой с зависимостями кешируется до изменения lock-файла.
COPY pyproject.toml poetry.lock ./

# Устанавливаем зафиксированные версии; sdku-test-tools приедет из Nexus как wheel.
RUN poetry install --no-root --only main

# Код тестов.
COPY . .

# Пайп запускает: pytest <набор> -m <маркер> -q
CMD ["poetry", "run", "pytest", "-q"]
