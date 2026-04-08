FROM mambaorg/micromamba:1.5.0

# Set environment name
ENV ENV_NAME=gatk-pipeline

# Ensure base env binaries are accessible
ENV PATH=/opt/conda/bin:$PATH

# Copy lockfile
COPY conda-lock.yml /tmp/conda-lock.yml

# Copy pipeline script
COPY variant-pipeline.sh /workspace/

# Install conda-lock inside container
RUN micromamba install -y -n base -c conda-forge conda-lock && \
    micromamba clean --all --yes

# Create environment from lockfile
RUN micromamba run -n base conda-lock install \
    --mamba \
    --prefix /opt/conda/envs/$ENV_NAME \
    /tmp/conda-lock.yml

# Activate environment by default
ENV PATH=/opt/conda/envs/$ENV_NAME/bin:$PATH

# Install Google Cloud SDK and crc32c component
RUN apt-get update && apt-get install -y curl gnupg lsb-release && \
    echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && apt-get install -y google-cloud-sdk && \
    gcloud components install crc32c --quiet && \
    apt-get clean

# Set working directory
WORKDIR /workspace

# Default shell
CMD ["/bin/bash"]