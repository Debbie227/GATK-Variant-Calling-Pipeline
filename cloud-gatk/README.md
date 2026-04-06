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
conda-lock -f environment.yml -p linux-64
```

### Next steps

- Permissions to use google cloud with gcloud auth and gcloud projects
- Lock the environment using conda lock
- Build and push to Google Container Registry using gcloud build
- Submit the job gcloud batch jobs