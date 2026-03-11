## Bash commands for GATK pipeline in codespaces

### Create directories and environment

```bash
# Create directory and begin pixi environment

mkdir gatk-variant-calling && cd $_

curl -fsSL https://pixi.sh/install.sh | bash
source ~/.bashrc

# Copy pixi.toml to directory
# Copy .gitignore to directory
pixi install
```

```bash
# Create file tree
mkdir -p data/raw \
        data/trimmed \
        reference \
        results
```
### Download data

```bash
# Download data from SRA
cd data/raw/

# Whole genome sequencing of Polish family chromosome 22
pixi run fasterq-dump -p SRR12023503 --split-files

# Zip files to keep storage small
gzip SRR12023503_1.fastq SRR12023503_2.fastq 
```

```bash
# Download Chr 22 reference genome
cd ../..

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
pixi run bwa index reference/genome.fasta
```
### QC and trim data

```bash
# Run FASTQC on raw files
mkdir -p results/qc/raw
pixi run fastqc data/raw/*.fastq.gz -o results/qc/raw
```

```python
# In a new terminal check out the fastqc results using an http server
python3 -m http.server 8000
```

```bash
# Trimming with fastp default settings
pixi run fastp -i data/raw/SRR12023503_1.fastq.gz -I data/raw/SRR12023503_2.fastq.gz \
 -o data/trimmed/SRR12023503_1.fastq.gz -O data/trimmed/SRR12023503_2.fastq.gz

# Run QC on trimmed reads
pixi run fastqc data/trimmed/*.fastq.gz -o results/qc/trimmed
```
### Align genome and create bam files
```bash
# Align the reads to the genome with bwa

pixi run bwa mem reference/genome.fasta data/trimmed/SRR12023503_1.fastq.gz data/trimmed/SRR12023503_2.fastq.gz \
 > results/aligned/SRR12023503.sam

# Try alignment and bam file creating in one step
pixi run bwa mem -t 8 reference/genome.fasta data/trimmed/SRR12023503_1.fastq.gz data/trimmed/SRR12023503_2.fastq.gz \
 | pixi run samtools sort -@8 -o results/aligned/SRR12023503.bam - \
 && pixi run samtools index results/aligned/SRR12023503.bam

```
```bash
# Check alignment rate, coverage depth, mapping quality, duplicate rate, insert size distribution
# Next step GATK duplicates
```