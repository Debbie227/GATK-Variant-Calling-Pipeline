# Bash commands for cloud pipeline

- Created variant-pipeline.sh with commands up to variant calling
- Created dockerfile to run pipeline in
- created job.json to submit to the cloud
- created environment.yaml for conda downloads

```bash
# Download data using fasterq-dump and upload to cloud bucket for use in pipeling
conda install bioconda::sra-tools
fasterq-dump -p SRR12023503 --split-files
# Connection failed
# Used pixi from the shell commands pipeline to download
# Commands in bash_commands.md
```

```bash
# Create a lock file with packages and dependancies 
pip install conda-lock
conda-lock -f environment.yaml -p linux-64
```

```bash
# Log into Google cloud via Google cloud docker container
docker run -it --rm \
    -v /workspaces/GATK-Variant-Calling-Pipeline/cloud-gatk:/app/ \
    gcr.io/google.com/cloudsdktool/google-cloud-cli:slim

# Inside the container login and set the project
gcloud auth login

gcloud config set project gatk-resources-490700

cd /app

# Build the docker image
# shell script is inside dockerfile. This must be re-built if the script is changed!
gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:latest

# Submit the job
gcloud batch jobs submit gatk-job \
  --location=us-central1 \
  --config=job.json

# Check if it worked
gcloud batch jobs describe gatk-job --location=us-central1
```

### Next steps

- Permissions to use google cloud with gcloud auth and gcloud projects
- Build and push to Google Container Registry using gcloud build
- Submit the job gcloud batch jobs