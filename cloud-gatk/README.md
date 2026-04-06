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
# Make pipeline executable Before sending to dockerfile
chmod +x variant-pipeline.sh

# Log into Google cloud via Google cloud docker container
# Free trial has $296.49 credits - check to see if this job reduces credits
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
# ERROR: (gcloud.builds.submit) Invalid value for [source]: Dockerfile required when specifying --tag
# dockerfile must have a capital D

cp dockerfile Dockerfile

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:latest
# Had to enable BATCH api - Added IAM permissions for Batch admin, Storage Object Admin
# Permissions had to be added to service account Not just IAM account
# Also needs logWriter permissions

# Builds are making it to Google Cloud!!
# Scrips should be made executable before going into dockerfile - add chmod +x outside of docker container -remove from Dockerfile
# Conda lock failed with "command not found"- add argument to install via mamba to dockerfile
# Error persists - install via micromamba instead of directly in bash and add environment path to dockerfile
# Job needed permission to upload aftifacts - also added permissions to read and write to cloud storage just in case

# Aftifact registry requires a docker repository to be built before pushing images
gcloud artifacts repositories create gcr.io \
    --repository-format=docker \
    --location=us \
    --description="GCR Compatibility Repository"

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:latest
# SUCCESS!!!

# Submit the job
gcloud batch jobs submit gatk-job \
  --location=us-central1 \
  --config=job.json
# Invalid JSON payload received. Unknown name "diskSizeGb"
# Changed all field names from CamelCase to snake_case - same error
# These LLMs don't know how to write a config. Break time and resume tomorrow https://docs.cloud.google.com/batch/docs/create-run-example-job 

# Check if it worked
gcloud batch jobs describe gatk-job --location=us-central1
```

### Next steps

- Submit the job gcloud batch jobs