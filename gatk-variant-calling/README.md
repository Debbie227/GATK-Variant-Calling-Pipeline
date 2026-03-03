## Building the GATK Variant Calling pipeline one command at a time in a Linux environment

### Getting started

A Variant Calling pipeline is...

GATK is ...

Creating this pipleine step by step allows the builder to troubleshoot and...

Bioinformatics tools use the Linux command line...

This pipeline uses a Pixi environment to...

### First create a directory and move into that directory
In the terminal type

```bash
mkdir gatk-variant-calling && cd $_
```
Learning to be a Linux ninja takes learning shortcuts in typing commands
The && allows for two commands to be run...
The $_ uses the last argument...

Other shortcuts include:
using tab to autocomplete

Moving back to the home folder
cd

Move up one directory
cd ..
cd ../..
cd -
ls -alh

Create parent directories at the same time 
mkdir -p chain/of/directories

### Download and install Pixi

Pixi uses uv under the hood to ensure that correct versions are chosen...

Different versions may not be compatible and may produce different results...

Copy the pixi.toml file contents into your folder to ensure the same versions are used...

The curl command will download pixi and install the program...

Bashrc file in Linux is... 
Source bashrc will allow the changes made to bashrc file to work....

Pixi install uses the toml file to create a virtual envirnment...

```bash
# Define pixi environment and dependancies 
touch pixi.toml

curl -fsSL https://pixi.sh/install.sh | bash
source ~/.bashrc

pixi install
```

Here is a breakdown of the pixi.toml file contents...

[workspace]
name = "gatk-variant-calling"
version = "0.1.0"
description = "GATK variant calling workflow with reproducible environment"
channels = ["conda-forge", "bioconda"]
platforms = ["linux-64"]

### Create a set of folders to put your data, reference genome, and results in

```bash
mkdir -p data reference results
cd reference
```

### Download all reference data needed for this workflow
```bash
# Download reference genome
curl -L -o genome.fasta \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/genome.fasta
curl -L -o genome.fasta.fai \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/genome.fasta.fai
curl -L -o genome.dict \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/genome.dict

# Download known sites for BQSR

    # Known snps from NCBI
curl -L -o dbsnp_146.hg38.vcf.gz \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/vcf/dbsnp_146.hg38.vcf.gz
curl -L -o dbsnp_146.hg38.vcf.gz.tbi \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/vcf/dbsnp_146.hg38.vcf.gz.tbi

    # Known indels from 1000 genomes Project
curl -L -o mills_and_1000G.indels.vcf.gz \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/vcf/mills_and_1000G.indels.vcf.gz
curl -L -o mills_and_1000G.indels.vcf.gz.tbi \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/vcf/mills_and_1000G.indels.vcf.gz.tbi
```

But wait! How do we choose a reference genome? What are the differences between genomes? ...


### Use BWA to index the reference genome

What is BWA and what does indexing do? ...

This command will give the following files:

...

```bash
# Index reference genome
cd ..
pixi run bwa index reference/genome.fasta
```

### Downloading our FASTQ data

This test data from nf-core is a small set of human illumina reads that is small enough to work with on a free server, yet larrge enough to get meaningful results to look at.

```bash
# Download test data for pipeline
cd data
curl -L -o test_1.fastq.gz \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/illumina/fastq/test_1.fastq.gz
curl -L -o test_2.fastq.gz \
  https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/illumina/fastq/test_2.fastq.gz

cd ..
```
## Now we are ready to begin part 2 - Taking our FASTQ reads and aligning them to the genome.
