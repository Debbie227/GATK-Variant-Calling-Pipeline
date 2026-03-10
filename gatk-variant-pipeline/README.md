## Initial commands for GATK pipeline in codespaces

## Initial commands for GATK pipeline in codespaces

```bash
# Create directory and begin pixi environment
mkdir gatk-variant-calling && cd $_

curl -fsSL https://pixi.sh/install.sh | bash
source ~/.bashrc

pixi install
```

```bash
# Create file tree
mkdir -p data/raw \
        data/trimmed \
        reference \
        results
```

```bash
# download small subset of data from SRA
cd data/raw/

pixi run fasterq-dump SRR37153337 \
  --split-files \
  -X 50000

# Error Failed to call external services.
# Conda may not have the latest version of SRA toolkit?

docker build -t sra-download .

# Same error

pixi run prefetch SRR37153337 \
    --max-size 41G

# Too big for codespaces to deal with...
# Time for a dataset that is smaller...

# Found whole genome sequencing of Polish family chromosome 22
pixi run fasterq-dump SRR12023503 --split-files
# This command takes a long time to run. -p or --progress could have shown progress bar
# Data size listed on SRA is 1.7GB. FASTQ-dump produced two 4.55GB fastq files - keep in mind for future downloads.
```

```bash
# Download Chr 22 reference genome
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

```bash
# Index reference genome
cd ..
pixi run bwa index reference/genome.fasta
```

```bash
# Run FASTQC on raw files
cd ../..
mkdir -p results/qc/raw
pixi run fastqc data/raw/*.fastq -o results/qc/raw
```

```python
# In a new terminal check out the fastqc results using an http server
python3 -m http.server 8000

# Yay! These actually look like proper results!!
# Needs some trimming on tail and some low quality scores
```

```bash
# Trimming with fastp default settings
pixi run fastp -i data/raw/SRR12023503_1.fastq -I data/raw/SRR12023503_2.fastq -o data/trimmed/SRR12023503_1.fastq -O data/trimmed/SRR12023503_2.fastq

# Should have saved output - copied to file

# Out of memory in codespace...
```

```bash
# Run fastqc on the trimmed reads
mkdir -p results/qc/trimmed

pixi run fastqc data/trimmed/*.fastq -o results/qc/trimmed
# Both samples failed to run
# uk.ac.babraham.FastQC.Sequence.SequenceFormatException: Midline 'TGAGCTATGTGTCCCCAAGGATGAGGCTGCCATTTCTCTCCTGGGCTTTTC' didn't start with '+' at 33018019
# uk.ac.babraham.FastQC.Sequence.SequenceFormatException: Ran out of data in the middle of a fastq entry.  Your file is probably truncated

# Did I run out of room and not save the files correctly? Zip input and output files to save space and deleted files from other pipeline.
cd data/raw
gzip SRR12023503_1.fastq SRR12023503_2.fastq 
# This takes a very long time but the files are now 1.06GB

cd ../..

pixi run fastp -i data/raw/SRR12023503_1.fastq.gz -I data/raw/SRR12023503_2.fastq.gz -o data/trimmed/SRR12023503_1.fastq.gz -O data/trimmed/SRR12023503_2.fastq.gz
# fastp.html and fasp.json were properly made this time

pixi run fastqc data/trimmed/*.fastq.gz -o results/qc/trimmed
# paired reads no longer have data below the 20 quality mark
```

```bash
# Align the reads to the genome with bwa

pixi run bwa mem reference/genome.fasta data/trimmed/SRR12023503_1.fastq.gz data/trimmed/SRR12023503_2.fastq.gz > results/aligned/SRR12023503.sam
# This step is a good point for a lunch break...and maybe a walk...and a nap... It takes a very long time to align all these sequences.
# The sam file is quite large - next time pipe directly to bam to not take up the space. | samtools sort -o SRR12023503.bam

# Next step sam -> bam
```