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

# Changed to mounted volume using cloud bucket - I assume this will copy all files to bucket during run making the copy command in the script not needed
# Which compute engine to use https://www.cloudkeeper.com/insights/blog/gcp-instance-types-explained-making-right-choice-your-workloads
# Added same location as bucket- transfering between locations costs more
# Changed the persistent cloud storage to local disk https://docs.cloud.google.com/batch/docs/create-run-job-storage#gcloud
# Data not copied via the shell pipeline should go away once the job is over

# New day - new docker instance. Re-run auth, set project, cd

gcloud batch jobs submit gatk-job \
  --location=us-west1 \
  --config=job.json

# Unknown name \"zones\"
# removed location as it is specified in jobs submit

# Job gatk-job-38b24a8f-2310-4f9c-a0f2-60370 was successfully submitted.

# Check if it worked
gcloud batch jobs describe gatk-job --location=us-west1

#   state: SCHEDULED

# Navigate to compute engine and there is a vm created!
# Navigate to batch and there is 1 task scheduled - not yet running

# There are a ton of logs already - looks like there is still permissions needed: Batch agent reporter

# replace ##### with service account number
gcloud projects add-iam-policy-binding gatk-resources-490700 --member="serviceAccount:#####-compute@developer.gserviceaccount.com" --role="roles/batch.agentReporter"

# The first run failed (though I'm still super excited I got the submission correct!)
# There are hundreds of log messages but I think the problem is:
# textPayload: "critical libmamba Cannot activate, prefix does not exist at: '/opt/conda/envs/gatk-pipeline'"

# The total cost of using Google Cloud so far is $0.07 - credits left $296.42

# Updated docker file to explicitly create a prefix path per VS code agent
```

```bash
# New terminal
# Deleted lowercase dockerfile which is now obsolete to avoid confusion with builds

docker build --no-cache -t gatk-pipeline-test-updated .
docker run --rm --entrypoint sh gatk-pipeline-test-updated -c 'ls -ld /opt/conda/envs/gatk-pipeline'
# The missing prefix exists now!

# I also realized that the versions in my yaml file are not the same as I used in my last pipeline
# Updated several versions
conda-lock -f environment.yaml -p linux-64
# The changed versions weren't compatible so I'll leave it alone.
```

```bash
# back to the gcloud docker command line
# The latest tag is a lie. Let's name it something more meaningful?

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2

gcloud batch jobs submit gatk-job2 \
  --location=us-west1 \
  --config=job.json

# This time I made it all the way to the shell script!
# Error: textPayload: "mkdir: cannot create directory ‘/mnt/disks’: Permission denied"

# Added the local-ssd name to the path from job.json so the script can properly make the directory
gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.1

gcloud batch jobs submit gatk-job3 \
  --location=us-west1 \
  --config=job.json

# For peace of mind I checked to see how many VMs I had and there is only one with the latest job :)
# No money has been spent during these job failures

# Same error textPayload: "mkdir: cannot create directory ‘/mnt/disks’: Permission denied"
# Added super user login to script
# Also added mount Path to json.jobs and rw option
# Use a local SSD: https://docs.cloud.google.com/batch/docs/create-run-job-storage#gcloud_3

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.2

gcloud batch jobs submit gatk-job4 \
  --location=us-west1 \
  --config=job.json

# Failed: /workspace/variant-pipeline.sh: line 8: sudo: command not found
# Remove sudo and try again
# Also changed retry to 1 - no reason to keep trying on these early failures

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.2

gcloud batch jobs submit gatk-job5 \
  --location=us-west1 \
  --config=job.json

# New error! /workspace/variant-pipeline.sh: line 13: gsutil: command not found
# I thought since it was a google cloud vm it'd have gsutil...
```