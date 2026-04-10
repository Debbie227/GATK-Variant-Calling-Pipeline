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
# Every build change must be updated in job.json

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
# Updated to gcloud storage in pipeline and added gcloud sdk to environment.yaml

# In other terminal
conda-lock -f environment.yaml -p linux-64

# back to docker terminal
gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.3

gcloud batch jobs submit gatk-job6 \
  --location=us-west1 \
  --config=job.json

# New errors! (gcloud.storage.cp) The following URLs matched no objects or files: gs://gatk-resource-bucket/data/SRR12023503_*.fastq.gz
# FutureWarning: You are using a Python version (3.10.14) which Google will stop supporting...

# There is no data folder in the bucket - changed the script to match the correct url
# Not sure where the really old python version is coming in...maybe the mamba image?
```

```bash
# micromamba does not have a python dependency and does not contain python https://micromamba-docker.readthedocs.io/en/latest/quick_start.html
# I'll add python in the environment since google cloud is looking for it
# Also changed the environment name to "base" per the micromamba docs

conda-lock -f environment.yaml -p linux-64
# python version does not work with lock file - docker build installs python 3.14.4 - removing python from environment

# Credits are down to $296.30 today - something has cost a few cents in the past two days

# New day - new docker instance. Re-run auth, set project, cd
docker run -it --rm \
    -v /workspaces/GATK-Variant-Calling-Pipeline/cloud-gatk:/app/ \
    gcr.io/google.com/cloudsdktool/google-cloud-cli:slim

# Inside the container login and set the project
gcloud auth login

gcloud config set project gatk-resources-490700

cd /app

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.4

gcloud batch jobs submit gatk-job7 \
  --location=us-west1 \
  --config=job.json

# There are so many error messages (many with the error "") that it is hard to tell the problem. It seems the gcloud needs a component maybe?
# This command requires the `gcloud-crc32c` component to be installed. Would you like to install the `gcloud-crc32c` component to continue command execution? (Y/n)?
# I've also been looking at the logs wrong - oldest messages are at the top - everything makes more sense now

# Added google cloud sdk and crc32c download to the Dockerfile and removed sdk from the environment
# https://docs.cloud.google.com/sdk/docs/install-sdk#deb

# In a new terminal
conda-lock -f environment.yaml -p linux-64

# In docker container
gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.5

# Build failed - List directory /var/lib/apt/lists/partial is missing. - Acquire (13: Permission denied)
# Removed sdk install from dockerfile and added back to environment along with crc32c
# Changed retry to 0 in json file

# In new terminal
conda-lock -f environment.yaml -p linux-64

# In docker container
gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.5

# Same error This command requires the `gcloud-crc32c` component
# Added the suggested command from the job logs to the dockerfile
# removed the component from environment.yaml

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.6

# Maybe I should check locally to see if the file exists before submitting again...
# Other terminal
docker build --no-cache -t gatk-pipeline-test .
# Too big...not enough space on codespaces
docker image prune -a
# Total reclaimed space: 243MB

# submit the job without checking it is then
gcloud batch jobs submit gatk-job9 \
  --location=us-west1 \
  --config=job.json

# The build failed with no module named pip so of course the job failed too
# Added pip - re-ran conda lock - re-submitted build 2.6

gcloud batch jobs submit gatk-job10 \
  --location=us-west1 \
  --config=job.json

# There were a ton of error level warnings on copying but it seems to have worked?
# BWA is indexing the ref genome! 100 iterations done at 1:50pm - time for a break

# Finished indexing, ran fastqc, ran trimgalore and created val_1 and val_2 files
# Ended with error: Read 2 output is truncated at sequence count: 18723539, please check your paired-end input files! Terminating...

# Nextflow would be nice since I could re-run steps without starting over from the beginning...
# Added filterpair to pipeline to ensure both files have the same sequences

# Cost of failed pipeline - 1hr 17min run  cost $0.02 - remaining credits $296.28 

# locked environment, ran cloud container, raw cloud auth, ran set project, cd

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.7

gcloud batch jobs submit gatk-job11 \
  --location=us-west1 \
  --config=job.json

# Error "This Spot VM is preempted. All unfinished tasks will be marked as failed with Batch exit code 50001."
# BWA failed at constructing the SA file due to the cheap vm no longer being available

gcloud batch jobs submit gatk-job12 \
  --location=us-west1 \
  --config=job.json

# Pipeline ran for 2 hours 3 min - failed mid BWA-MEM with no error code - alignment ran from 18:48 - 19:08 - local bwa-mem ran for 5 hours
# I guess I'll try it again, but it's concerning that it's failed twice before finishing an alignment
# Added one retry to the json file

gcloud batch jobs submit gatk-job13 \
  --location=us-west1 \
  --config=job.json

# cpu utilization for indexing is 12% - reserved cpus 8 cpu usage 1

# fastq utils posts thousands of messages - look for quiet mode? - not thousands....over 18.5 million error messages on the log
# quiet mode doesn't exist - manually redirect stdout next update using: command > /dev/null
# cpu went up to 36% - reserved cpus usage to 3

# bwa-mem cpu utilization 29% - cpu usage 3
# memory usage jumped to 73% in 3 min - 97% 6 cpu usage - leveled off at 99% 8cpu max usage
# memory usage may be the reson the previous run failed. Lower the threads used or increase vm power? - Will see in the morning if the job runs.

# Error samtools depth: Data is not position sorted
# Had alignment check before index and sort
# Fixed order of commands and added stdout redirect to pipeline

# runtime 3 hours 40min - credit at $295.13
```

```bash
docker run -it --rm \
    -v /workspaces/GATK-Variant-Calling-Pipeline/cloud-gatk:/app/ \
    gcr.io/google.com/cloudsdktool/google-cloud-cli:slim

gcloud auth login

gcloud config set project gatk-resources-490700

cd /app

gcloud builds submit --tag gcr.io/gatk-resources-490700/gatk-pipeline:v2.8

gcloud batch jobs submit gatk-job14 \
  --location=us-west1 \
  --config=job.json

# Job succeded! 
# redirecting stdout did not stop the errors from being logged in google cloud
# results folder does not have sample number - fix at some point
# Results folder has copy of original fastq files - do not need two copies in one bucket - fix at some point

# Alignment 99.99% mapped - 95.77% matched pairs - 0.01% singletons

# Still need to add: VSQR, Functional annotation, variant statistics
# Creating separate shell script to test next set of commands

# Next steps: double check shell script, download vcf from google bucket, get docker container with GATK, run vcf pipeline script
```

```bash
# Get vcf from variant-pipeline
 mkdir cloud-gatk/vcf-results
 cd cloud-gatk/vcf-results/

docker run -it --rm \
    -v /workspaces/GATK-Variant-Calling-Pipeline/cloud-gatk/vcf-results:/app/ \
    gcr.io/google.com/cloudsdktool/google-cloud-cli:slim

gcloud auth login

cd /app

gcloud storage cp gs://gatk-resource-bucket/results/SRR12023503.vcf.gz .

exit

# Moved vcf pipeline to vcf-results folder to make things easier

# Make sure shell script has executable permissions
chmod +x vcf-pipeline.sh

# Use broad institutes gatk docker image - should have all dependancies 
docker run -it --rm \
    -v /workspaces/GATK-Variant-Calling-Pipeline/cloud-gatk/vcf-results:/app/data \
    broadinstitute/gatk:4.6.2.0

# Ran out of space in codespaces just downloading the image
# Deleting pixi folder to make room
# Now there is 10k+ git changes...Going to open a new copdespace and re-run these commands

# cannot find mounted drive
ls
# this image opens under the folder gatk not under app or root
# found shell script in /app/data folder

# back to gatk

/app/data/vcf-pipeline.sh

# Variant recalibrator error: A USER ERROR has occurred: Illegal argument value: Positional arguments were provided ', }' but no positional argument is defined for this tool.
# Changed formatting https://gatk.broadinstitute.org/hc/en-us/articles/360036510892-VariantRecalibrator

# A USER ERROR has occurred: Illegal argument value: Positional arguments were provided ', }' but no positional argument is defined for this tool.
# A USER ERROR has occurred: Argument output was missing: Argument 'output' is required
# Removed : after resource

# A USER ERROR has occurred: Argument resource has a bad value: hapmap,known=false,training=true,truth=true,prior=15.0:gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz. Failure constructing 'FeatureInput' from the string 'hapmap,known=false,training=true,truth=true,prior=15.0:gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz'.

# Tried to change just HAPMAP gs:// resource to a variable to see if it will work
# Same error - Error is not on reference though?
# After trying a ton of different methods with different spaces and colons and using variables I got a new error!
# /app/data/vcf-pipeline.sh: line 9: 1000G=gs://gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz: No such file or directory
# back to Illegal argument value...
# Using two colons gives - A USER ERROR has occurred: No argument value found for tagged argument: resource:hapmap,known=false,training=true,truth=true,prior=15.0:gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz
# I don't think the gs:// is going to work

# No colons - A USER ERROR has occurred: Illegal argument value: Positional arguments were provided ',gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz{gs://gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz{gs://gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz{gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.gz{ }' but no positional argument is defined for this tool.

# Used wget to download files
# Copied code exactly from broadinstitute.org

# Files has slightly different names - fixed 

./vcf-pipeline.sh

# New error! - A USER ERROR has occurred: An index is required but was not found for file hapmap:/app/data/hapmap_3.3.hg38.vcf.gz. Support for unindexed block-compressed files has been temporarily disabled. Try running IndexFeatureFile on the input.
# Need the index files also...

# After I thought I tried everything I re-put in the gs:// and it worked...

# Added indexing to vcf

# Made it through indexing and variant recal!
# Now same annoying error with VSQR - A USER ERROR has occurred: Illegal argument value: Positional arguments were provided ', }' but no positional argument is defined for this tool.

# I DO NOT KNOW WHAT IS CAUSING IT

# Copying and pasting from the gatk website worked and now the next command has the error...will copy paste all remaining commands

# ./vcf-pipeline.sh: line 56: snpEff: command not found
# I wasn't sure if it'd be in the docker container or not

conda install bioconda::snpeff
# Collecting package metadata (repodata.json): | Terminated
# Newest version unsupported by linux64 - last supported version 4.3.1t
conda install bioconda::snpeff:4.3.1t
# Collecting package metadata (repodata.json): | Terminated

# For now I'll run snpEff in a separate docker container
# New terminal

docker run -it --rm \
  -v /workspaces/GATK-Variant-Calling-Pipeline/cloud-gatk/vcf-results:/app/ \
  staphb/snpeff:5.2f

# does not run interactively - kicks me out of the container after displaying some information

# This one hasn't been updated in 7 years but it works
# Open in the data folder - not in app
docker run -it --rm \
  -v /workspaces/GATK-Variant-Calling-Pipeline/cloud-gatk/vcf-results:/data \
  biocontainers/snpeff:v4.1k_cv3

snpEff ann \
    -Xmx32g \
    -stats SRR12023503_annotation_stats.html \
    GRCh38.105 \
    SRR12023503_filtered.vcf.gz \
    > SRR12023503_annotated.vcf

# java.lang.RuntimeException: Property: 'GRCh38.105.genome' not found

snpEff ann \
    -Xmx32g \
    -stats SRR12023503_annotation_stats.html \
    GRCh38 \
    SRR12023503_filtered.vcf.gz \
    > SRR12023503_annotated.vcf

# java.lang.RuntimeException:     ERROR: Cannot read file '/home/biodocker/bin/snpEff/./data/GRCh38/snpEffectPredictor.bin'. You can try to download the database by running the following command: java -jar snpEff.jar download GRCh38

java -jar snpEff.jar download GRCh38

# Error: Unable to access jarfile snpEff.jar
# No documentation on this super old docker container...

# GATK container - lets finish the pipeline minus the annotation
bcftools stats SRR12023503_filtered.vcf.gz > SRR12023503_variant_stats.txt

# number of SNPs:	66013
# number of indels:	13227

bcftools view -v snps SRR12023503_filtered.vcf.gz | bcftools query -f '.\n' | wc -l > SRR12023503_snp_count.txt

bcftools view -v indels SRR12023503_filtered.vcf.gz | bcftools query -f '.\n' | wc -l > SRR12023503_indel_count.txt

# These are both in the stats file...not sure why we need separate text files with a single number


```
