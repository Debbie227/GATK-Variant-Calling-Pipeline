#!/bin/bash
set -euo pipefail

# Variables
SAMPLE=SRR12023503
BUCKET=gatk-resource-bucket

WORKDIR=/mnt/disks/local-ssd/work # Directory for storing large working files in Google Cloud Batch
mkdir -p $WORKDIR
cd $WORKDIR

echo "Copying input data..."
gsutil cp gs://$BUCKET/data/${SAMPLE}_*.fastq.gz .

echo "Copying reference..."
gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta .
gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.fai .
gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dict .

echo "Indexing reference..."
bwa index Homo_sapiens_assembly38.fasta

echo "Running FastQC..."
fastqc ${SAMPLE}_*.fastq.gz

echo "Trimming reads..."
trim_galore \
  --paired \
  --quality 20 \
  --length 50 \
  ${SAMPLE}_1.fastq.gz ${SAMPLE}_2.fastq.gz

echo "Running alignment..."
bwa mem -t 8 \
  -R "@RG\tID:$SAMPLE\tSM:$SAMPLE\tPL:ILLUMINA" \
  Homo_sapiens_assembly38.fasta \
  ${SAMPLE}_1_val_1.fq.gz ${SAMPLE}_2_val_2.fq.gz \
  > ${SAMPLE}.sam

echo "Performing alignment check..."
samtools flagstat ${SAMPLE}.sam > ${SAMPLE}.align_stats.txt
samtools depth ${SAMPLE}.sam > ${SAMPLE}.depth.txt

echo "Sorting BAM..."
samtools sort ${SAMPLE}.sam -o ${SAMPLE}.bam
samtools index ${SAMPLE}.bam

echo "Marking duplicates..."
gatk MarkDuplicates \
  -I ${SAMPLE}.bam \
  -O ${SAMPLE}_marked.bam \
  -M metrics.txt \
  --CREATE_INDEX true

echo "BQSR..."
gatk BaseRecalibrator \
  -I ${SAMPLE}_marked.bam \
  -R Homo_sapiens_assembly38.fasta \
  --known-sites gs://gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
  --known-sites gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.gz \
  -O recal.table

gatk ApplyBQSR \
  -I ${SAMPLE}_marked.bam \
  -R Homo_sapiens_assembly38.fasta \
  --bqsr-recal-file recal.table \
  -O ${SAMPLE}_recal.bam

echo "Variant calling..."
gatk HaplotypeCaller \
  -R Homo_sapiens_assembly38.fasta \
  -I ${SAMPLE}_recal.bam \
  -O ${SAMPLE}.vcf.gz

echo "Uploading results..."
gsutil cp *.fastq.gz *.bam *.bai *.depth.txt *.align_stats.txt *.vcf.gz gs://$BUCKET/results/

echo "DONE"