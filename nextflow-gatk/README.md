### Bash commands for Nextflow pipeline

- created initial nextflow.config file
- created initial main.nf nextflow file
- created initial params.config variable definition file

```bash
# Started writing Nextflow workflow
# Next steps test mini pipeline
# - Add workflow to the bottom of the pipeline (like calling the defined functions called DAG)
# - Use nextflow container nextflow/nextflow:26.03.2-edge
# - Need to figure out how to use GCP inside container

# Maybe add emit to pipeline to label outputs
```

```bash
# Lets try to run the pipeline through trimming
docker run -it --rm \
    -v /workspaces/GATK-Variant-Calling-Pipeline/nextflow-gatk:/app/ \
    nextflow/nextflow:26.03.2-edge
# Exits the container - Lets try to specify that it should open bash?

docker run -it --rm \
    -v /workspaces/GATK-Variant-Calling-Pipeline/nextflow-gatk:/app/ \
    --entrypoint /bin/bash \
    nextflow/nextflow:26.03.2-edge

cd app

nextflow run main.nf \
    -config nextflow.config \
    -params-file params.config \
    -work-dir gs://gatk-resource-bucket/work \
    -resume

# Not a valid params file extension: params.config -- It must be one of the following: json,yml,yaml
# parameter file should be included in nextflow.config - not a separate line on nextflow run https://vibbits-nextflow-workshop.readthedocs.io/en/latest/nextflow/configs.html
# Added line to nextflow.config

nextflow run main.nf \
    -config nextflow.config \
    -work-dir gs://gatk-resource-bucket/work \
    -resume

# Error: main.nf:9:16: Unexpected input: 'from'
# Changed line to     sample_ch = Channel.of(params.sample)

nextflow run main.nf \
    -config nextflow.config \
    -work-dir gs://gatk-resource-bucket/work \
    -resume

# WARN: Unrecognized config option 'process.preemptible'
# WARN: Unrecognized config option 'google.region'
# Error main.nf:39:1: Invalid process definition -- check for missing or out-of-order section labels

# The config file created via gpt is completely wrong - https://seqera.io/blog/nextflow-with-gbatch/
# https://docs.seqera.io/nextflow/reference/config#google
# changed 'region' to 'location'
# Added container
# Removed machine specs - each process is a different VM? - process cpus and memory can be added in the script section after command: --cpus $task.cpus --mem $task.memory
# https://docs.seqera.io/nextflow/process#outputs

# Can preview workflow without running it
nextflow run main.nf -preview -with-dag
# Config errors no longer show, still invalid process definition

# Added comma, changed "" to '' https://docs.seqera.io/nextflow/reference/process

nextflow run main.nf -preview -with-dag
# Error main.nf:3:1: Statements cannot be mixed with script declarations -- move statements into a process, workflow, or function

# Got rid of channel header
# Same error
# Channels used to be placed at the top of the script but now must be under workflow - many old pipelines still show channels on top

# Error main.nf:34:15: `match_` is not defined
# Removed extra $
# Error main.nf:8:1: `samples` is not defined
# Why does this not catch errors in order??
# Removed samples - wasn't sure why it was there but it autopopulated when typing

nextflow run main.nf -preview -with-dag -config nextflow.config
# Process `DOWNLOAD_FASTQ` declares 1 input but was called with 0 arguments
# Deleting all of the log and html files - also going to stop using the with dag because I don't need empty plots being generated

nextflow run main.nf -preview -config nextflow.config

# Changed channel.frompath to channel.of because it is a string not a path
# Yay! the error is now: Your default credentials were not found. To set up Application Default Credentials for your environment...

# I knew this would be coming since I haven't set up the credentials yet
```