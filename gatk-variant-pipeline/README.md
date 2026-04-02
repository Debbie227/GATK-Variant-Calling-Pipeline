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
# Download reference genome
cd ../..

pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta reference/genome.fasta
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.fai reference/
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dict reference/

# Download known sites for BQSR

# HapMap: High-quality SNPs used for training variant filters
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz.tbi
 
# 1000 Genomes Omni: Another high-quality variant set for training
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz.tbi
 
# 1000 Genomes high-confidence SNPs: Large collection of validated variants
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi
 
# Mills and 1000G indels: High-quality insertions and deletions
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi
 
# dbSNP: Database of known variants - helps identify novel vs. known variants
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.gz
wget https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.gz.tbi
```

```bash
# Index reference genome
pixi run bwa index -a bwtsw ref/genome.fasta
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
    --known-sites reference/Homo_sapiens_assembly38.dbsnp138.vcf.gz \
    --known-sites reference/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
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

# Check insert size metrics
pixi run gatk CollectInsertSizeMetrics \
    -I results/aligned/SRR12023503_recalibrated.bam \
    -O results/aligned/SRR12023503_insert_size_metrics.txt \
    -H results/aligned/SRR12023503_insert_size_histogram.pdf
```
### Variant Calling
```bash
# Call variants from all sites
gatk HaplotypeCaller \
    -R reference/genome.fasta \
    -I results/aligned/SRR12023503_recalibrated.bam \
    -O results/aligned/SRR12023503.g.vcf.gz \
    -ERC GVCF \
    --dbsnp reference/Homo_sapiens_assembly38.dbsnp138.vcf.gz

# Convert GVCF to standard VCF format
gatk GenotypeGVCFs \
    -R reference/genome.fasta \
    -V results/aligned/SRR12023503.g.vcf.gz \
    -O results/aligned/SRR12023503_raw_variants.vcf.gz
```
