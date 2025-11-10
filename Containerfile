FROM registry.fedoraproject.org/fedora:41

RUN dnf -y install \
      python3 \
      python3-pip \
      curl \
      gcc \
      python3-devel \
      postgresql-devel \
  && dnf clean all

# Install PDM only for build-time export
RUN python3 -m pip install --no-cache-dir -U pip pdm

WORKDIR /app

# Copy manifests first
COPY pyproject.toml pdm.lock* ./

# Create system venv outside app source dir
ENV VENV_PATH=/opt/venv
RUN python3 -m venv ${VENV_PATH}
RUN ${VENV_PATH}/bin/pip install --no-cache-dir -U pip wheel setuptools

# Export deps from PDM -> install into venv
RUN pdm export --prod -f requirements --without-hashes -o /tmp/requirements.txt \
 && ${VENV_PATH}/bin/pip install --no-cache-dir -r /tmp/requirements.txt

# Copy app code
COPY . .

EXPOSE 8000

# Sanity check
RUN ${VENV_PATH}/bin/python -c "import uvicorn, fastapi; print('venv_ok')"

# Run Uvicorn
CMD ["./run_uvicorn.sh"]
