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
# ensure paired ends match and remove unmatched pairs
pixi run fastq_filterpair \
    data/raw/SRR12023503_1.fastq.gz data/raw/SRR12023503_2.fastq.gz \
    data/raw/match_SRR12023503_1.fastq.gz data/raw/match_SRR12023503_2.fastq.gz \
    data/raw/SRR12023503_single.fastq.gz
```
```bash
# Run FASTQC on raw files
mkdir -p results/qc/raw
pixi run fastqc data/raw/match*.fastq.gz -o results/qc/raw
```

```python
# In a new terminal check out the fastqc results using an http server
python3 -m http.server 8000
```

```bash
# Trimming with trim galore
pixi run trim_galore \
    --paired \
    --quality 20 \
    --length 50 \
    --fastqc \
    --fastqc_args "--outdir results/qc/trimmed/" \
    --output_dir data/trimmed/ \
    data/raw/match_SRR12023503_1.fastq.gz \
    data/raw/match_SRR12023503_2.fastq.gz

# Check QC on trimmed reads
```
### Align genome and create bam files
```bash
# Align the reads to the genome with bwa

pixi run bwa mem \
    -t $8 \
    -M \
    -P \
    -R "@RG\tID:SRR12023503\tSM:SRR12023503\tPL:ILLUMINA\tLB:SRR12023503_lib" \
    reference/genome.fasta \
    data/trimmed/match_SRR12023503_1_val_1.fq.gz \
    data/trimmed/match_SRR12023503_2_val_2.fq.gz \
    > results/aligned/SRR12023503.sam

# Convert the sam file to sorted bam
pixi run samtools sort results/aligned/SRR12023503.sam -o results/aligned/SRR12023503.bam

# Index the bam file
pixi run samtools index results/aligned/SRR12023503.bam
```

### Check alignment quality and coverage
```bash
# Check alignment rate, coverage depth, mapping quality, duplicate rate, insert size distribution
pixi run samtools flagstat results/aligned/SRR12023503.bam > results/qc/trimmed/SRR12023503_align_stats.txt

pixi run samtools depth results/aligned/SRR12023503.bam -o results/qc/trimmed/SRR12023503_depth.txt

pixi run gatk MarkDuplicates \
    -I results/aligned/SRR12023503.bam \
    -O results/aligned/SRR12023503_marked_duplicates.bam \
    -M results/aligned/SRR12023503_duplicate_metrics.txt \
    --CREATE_INDEX true
```
### Base quality score recalibration
```bash
# Generate recalibration table using known variants
pixi run gatk BaseRecalibrator \
    -I results/aligned/SRR12023503.bam \
    -R reference/genome.fasta \
    --known-sites reference/mills_and_1000G.indels.vcf.gz \
    --known-sites reference/dbsnp_146.hg38.vcf.gz \
    -O results/aligned/SRR12023503_recal_data.table

# Apply marked duplicates and recal data
pixi run gatk ApplyBQSR \
    -I results/aligned/SRR12023503_marked_duplicates.bam \
    -R reference/genome.fasta \
    --bqsr-recal-file results/aligned/SRR12023503_recal_data.table \
    -O results/aligned/SRR12023503_recalibrated.bam
```

### Quality control
```bash
# Check alignment metrics
pixi run gatk CollectAlignmentSummaryMetrics \
    -R reference/genome.fasta \
    -I results/aligned/SRR12023503_recalibrated.bam \
    -O results/aligned/SRR12023503_alignment_summary.txt
```