#!/bin/bash
#
# GATK Variant Calling Pipeline - Complete Best Practices (16 Steps)
# Following GATK Option 2: GVCF mode + hard filtering
# Written by Giang Nguyen

set -euo pipefail

# Configuration
SAMPLE="${1:-sample1}"  # Accept sample name as argument
THREADS=2
DATA_DIR="data"
REF_DIR="reference"
RESULTS_DIR="results"

# Reference files
REFERENCE="${REF_DIR}/genome.fasta"
DBSNP="${REF_DIR}/dbsnp_146.hg38.vcf.gz"
KNOWN_INDELS="${REF_DIR}/mills_and_1000G.indels.vcf.gz"

# Input files
FASTQ_R1="${DATA_DIR}/${SAMPLE}_R1.fastq.gz"
FASTQ_R2="${DATA_DIR}/${SAMPLE}_R2.fastq.gz"

# Output directories
QC_DIR="${RESULTS_DIR}/qc/${SAMPLE}"
TRIMMED_DIR="${RESULTS_DIR}/trimmed/${SAMPLE}"
ALIGNED_DIR="${RESULTS_DIR}/aligned/${SAMPLE}"
VAR_DIR="${RESULTS_DIR}/var/${SAMPLE}"

# Create directories
mkdir -p ${QC_DIR} ${TRIMMED_DIR} ${ALIGNED_DIR} ${VAR_DIR}

# Step 1: FastQC on raw reads
echo "[$(date)] Step 1: Running FastQC on raw reads..."
fastqc -o ${QC_DIR} -t ${THREADS} ${FASTQ_R1} ${FASTQ_R2}
echo "[$(date)] FastQC completed"

# Step 2: Adapter trimming with Trim Galore
echo "[$(date)] Step 2: Adapter trimming with Trim Galore..."
trim_galore \
    --paired \
    --quality 20 \
    --length 50 \
    --fastqc \
    --output_dir ${TRIMMED_DIR} \
    ${FASTQ_R1} ${FASTQ_R2}
echo "[$(date)] Adapter trimming completed"

# Step 3: Alignment with BWA-MEM
echo "[$(date)] Step 3: Aligning reads with BWA-MEM..."
bwa mem -t ${THREADS} -M \
    -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA\tLB:${SAMPLE}_lib" \
    ${REFERENCE} ${TRIMMED_R1} ${TRIMMED_R2} | \
    samtools view -Sb - > ${ALIGNED_BAM}

# Step 4: Sort BAM file
echo "[$(date)] Step 4: Sorting BAM file..."
samtools sort -@ ${THREADS} -o ${SORTED_BAM} ${ALIGNED_BAM}

# Step 5: Mark Duplicates
echo "[$(date)] Step 5: Marking duplicates with GATK..."
gatk MarkDuplicates \
    -I ${SORTED_BAM} \
    -O ${DEDUP_BAM} \
    -M ${METRICS} \
    --CREATE_INDEX true

# Step 6: Generate BQSR recalibration table
echo "[$(date)] Step 6: Generating BQSR recalibration table..."
gatk BaseRecalibrator \
    -I ${DEDUP_BAM} \
    -R ${REFERENCE} \
    --known-sites ${DBSNP} \
    --known-sites ${KNOWN_INDELS} \
    -O ${RECAL_TABLE}

# Step 7: Apply BQSR
echo "[$(date)] Step 7: Applying BQSR..."
gatk ApplyBQSR \
    -I ${DEDUP_BAM} \
    -R ${REFERENCE} \
    --bqsr-recal-file ${RECAL_TABLE} \
    -O ${RECAL_BAM}

# Step 8: Collect alignment quality metrics
echo "[$(date)] Step 8: Collecting alignment quality metrics..."
gatk CollectAlignmentSummaryMetrics \
    -R ${REFERENCE} \
    -I ${RECAL_BAM} \
    -O ${QC_DIR}/${SAMPLE}_alignment_summary.txt

gatk CollectInsertSizeMetrics \
    -I ${RECAL_BAM} \
    -O ${QC_DIR}/${SAMPLE}_insert_size_metrics.txt \
    -H ${QC_DIR}/${SAMPLE}_insert_size_histogram.pdf

# Step 9: Variant calling with HaplotypeCaller in GVCF mode
echo "[$(date)] Step 9: Calling variants with HaplotypeCaller in GVCF mode..."
gatk HaplotypeCaller \
    -R ${REFERENCE} \
    -I ${RECAL_BAM} \
    -O ${GVCF} \
    -ERC GVCF \
    --dbsnp ${DBSNP}

# Step 10: Genotyping GVCF to VCF
echo "[$(date)] Step 10: Genotyping GVCF to VCF..."
gatk GenotypeGVCFs \
    -R ${REFERENCE} \
    -V ${GVCF} \
    -O ${RAW_VCF}

# Step 11: Hard filtering SNPs
echo "[$(date)] Step 11: Hard filtering SNPs..."
# Select SNPs
gatk SelectVariants \
    -R ${REFERENCE} \
    -V ${RAW_VCF} \
    --select-type-to-include SNP \
    -O ${VAR_DIR}/${SAMPLE}_raw_snps.vcf.gz

# Apply filters (RELAXED for test data)
# NOTE: For production WGS (30x+ coverage), use stricter thresholds:
#   QD < 2.0, QUAL < 30.0, SOR > 3.0, FS > 60.0, MQ < 40.0
gatk VariantFiltration \
    -R ${REFERENCE} \
    -V ${VAR_DIR}/${SAMPLE}_raw_snps.vcf.gz \
    -O ${FILTERED_SNP_VCF} \
    --filter-expression "QD < 1.0" --filter-name "QD1" \
    --filter-expression "QUAL < 10.0" --filter-name "QUAL10" \
    --filter-expression "SOR > 10.0" --filter-name "SOR10" \
    --filter-expression "FS > 100.0" --filter-name "FS100" \
    --filter-expression "MQ < 20.0" --filter-name "MQ20"

# Step 12: Hard filtering Indels
echo "[$(date)] Step 12: Hard filtering indels..."
# Select Indels
gatk SelectVariants \
    -R ${REFERENCE} \
    -V ${RAW_VCF} \
    --select-type-to-include INDEL \
    -O ${VAR_DIR}/${SAMPLE}_raw_indels.vcf.gz

# Apply filters (RELAXED for test data)
# NOTE: For production WGS (30x+ coverage), use stricter thresholds:
#   QD < 2.0, QUAL < 30.0, FS > 200.0
gatk VariantFiltration \
    -R ${REFERENCE} \
    -V ${VAR_DIR}/${SAMPLE}_raw_indels.vcf.gz \
    -O ${FILTERED_INDEL_VCF} \
    --filter-expression "QD < 1.0" --filter-name "QD1" \
    --filter-expression "QUAL < 10.0" --filter-name "QUAL10" \
    --filter-expression "FS > 300.0" --filter-name "FS300"

# Step 13: Merge filtered variants
echo "[$(date)] Step 13: Merging filtered variants..."
gatk MergeVcfs \
    -I ${FILTERED_SNP_VCF} \
    -I ${FILTERED_INDEL_VCF} \
    -O ${FINAL_VCF}
# Step 14: Functional annotation with SnpEff
echo "[$(date)] Step 14: Annotating variants with SnpEff..."
gunzip -c ${FINAL_VCF} > ${VAR_DIR}/${SAMPLE}_filtered.vcf
snpeff -v GRCh38.mane.1.0.refseq \
    ${VAR_DIR}/${SAMPLE}_filtered.vcf \
    > ${ANNOTATED_VCF}
bgzip ${ANNOTATED_VCF}
tabix -p vcf ${ANNOTATED_VCF}.gz

# Step 15: Variant statistics
echo "[$(date)] Step 15: Generating variant statistics..."
bcftools stats ${RAW_VCF} > ${VAR_DIR}/${SAMPLE}_variant_stats_raw.txt
bcftools stats -f "PASS" ${FINAL_VCF} > ${VAR_DIR}/${SAMPLE}_variant_stats_filtered.txt

# Step 16: Generate visualization files
echo "[$(date)] Step 16: Generating visualization files..."
# Convert VCF to BED
zcat ${FINAL_VCF} | grep -v "^#" | \
    awk '{print $1"\t"$2-1"\t"$2"\t"$3}' \
    > ${VAR_DIR}/${SAMPLE}_variants.bed

# Create bedGraph for depth
samtools depth ${RECAL_BAM} | \
    awk '{print $1"\t"$2-1"\t"$2"\t"$3}' \
    > ${VAR_DIR}/${SAMPLE}_depth.bedgraph

echo "=========================================="
echo "Pipeline Completed Successfully!"
echo "=========================================="
echo "Results:"
echo "  - QC reports: ${QC_DIR}/"
echo "  - Trimmed reads: ${TRIMMED_DIR}/"
echo "  - Final BAM: ${RECAL_BAM}"
echo "  - GVCF: ${GVCF}"
echo "  - Raw Variants VCF: ${RAW_VCF}"
echo "  - Filtered VCF: ${FINAL_VCF}"
echo "  - Annotated VCF: ${ANNOTATED_VCF}.gz"
echo "  - Variant statistics: ${VAR_DIR}/"

echo
echo "Quick Quality Control Summary:"
echo "------------------------------"
echo "Alignment metrics:"
samtools flagstat ${RECAL_BAM}

echo
echo "Duplication rate:"
grep "^LIBRARY" -A 1 ${METRICS} | tail -1 | awk '{print $9}'

echo
echo "Variant counts (Raw):"
echo "  SNPs:" $(bcftools view -v snps ${RAW_VCF} | grep -v "^#" | wc -l)
echo "  Indels:" $(bcftools view -v indels ${RAW_VCF} | grep -v "^#" | wc -l)

echo
echo "Variant counts (Filtered - PASS only):"
echo "  SNPs:" $(bcftools view -f "PASS" -v snps ${FINAL_VCF} | grep -v "^#" | wc -l)
echo "  Indels:" $(bcftools view -f "PASS" -v indels ${FINAL_VCF} | grep -v "^#" | wc -l)
echo "=========================================="