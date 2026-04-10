#!/bin/bash
set -euo pipefail

# Variables
SAMPLE=SRR12023503
REFERENCE=gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta

echo "Recalibrating SNPs..."
gatk VariantRecalibrator \
    -R ${REFERENCE} \
    -V ${SAMPLE}.vcf.gz \
    --resource:hapmap,known=false,training=true,truth=true,prior=15.0 \
        gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz \     # Highest quality training set
    --resource:omni,known=false,training=true,truth=false,prior=12.0 \
        gs://gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz \  # High quality, slightly lower confidence
    --resource:1000G,known=false,training=true,truth=false,prior=10.0 \
        gs://gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz \  # Large training set
    --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 \
        gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.gz \  # Known variants (not for training)
    -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR \  # Variant annotations to use
    -mode SNP \             # Process SNPs only
    -O ${SAMPLE}_snps.recal \
    --tranches-file ${SAMPLE}_snps.tranches
 
 gatk ApplyVQSR \
    -R ${REFERENCE} \
    -V ${SAMPLE}.vcf.gz \
    --recal-file ${SAMPLE}_snps.recal \
    --tranches-file ${SAMPLE}_snps.tranches \
    -mode SNP \
    --truth-sensitivity-filter-level 99.0 \  # Keep 99% of true variants (high sensitivity)
    -O ${SAMPLE}_snps_recalibrated.vcf.gz

echo "Recalibrating Indels..."
gatk VariantRecalibrator \
    -R ${REFERENCE} \
    -V ${SAMPLE}_snps_recalibrated.vcf.gz \
    --resource:mills,known=false,training=true,truth=true,prior=12.0 \
        gs://gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \  # High-quality indels
    --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 \
        gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.gz \
    -an QD -an ReadPosRankSum -an FS -an SOR \  # Fewer annotations for indels
    -mode INDEL \
    --max-gaussians 4 \
    -O ${SAMPLE}_indels.recal \
    --tranches-file ${SAMPLE}_indels.tranches

gatk ApplyVQSR \
    -R ${REFERENCE} \
    -V ${SAMPLE}_snps_recalibrated.vcf.gz \
    --recal-file ${SAMPLE}_indels.recal \
    --tranches-file ${SAMPLE}_indels.tranches \
    -mode INDEL \
    --truth-sensitivity-filter-level 95.0 \
    -O ${SAMPLE}_filtered.vcf.gz

echo "Creating Functional Annotation..."
snpEff ann \
    -Xmx32g \    # Allocate 32GB memory for large genomes
    -stats ${SAMPLE}_annotation_stats.html \  # Generate stats report
    GRCh38.105 \  # Latest Ensembl-based database version
    ${SAMPLE}_filtered.vcf.gz \
    > ${SAMPLE}_annotated.vcf

gatk VariantsToTable \
    -V ${SAMPLE}_annotated.vcf \
    -F CHROM -F POS -F REF -F ALT -F QUAL -F ANN \  # Select specific fields to extract
    -O ${SAMPLE}_variants_table.tsv

echo "Generating Variant Statistics..."
bcftools stats ${SAMPLE}_filtered.vcf.gz > ${SAMPLE}_variant_stats.txt
 
# Count different types of variants
# SNPs (single nucleotide polymorphisms)
bcftools view -v snps ${SAMPLE}_filtered.vcf.gz | bcftools query -f '.\n' | wc -l > ${SAMPLE}_snp_count.txt
 
# Indels (insertions and deletions)
bcftools view -v indels ${SAMPLE}_filtered.vcf.gz | bcftools query -f '.\n' | wc -l > ${SAMPLE}_indel_count.txt

# Quick QC Summary Script for WGS Analysis
# This script extracts key quality metrics from all analysis steps
 
echo "========================================="
echo "WGS Quality Control Summary for ${SAMPLE}"
echo "========================================="
echo
 
echo "=== ALIGNMENT QUALITY ==="
echo -n "Mapping Rate: "
grep -A1 "FIRST_OF_PAIR" ${SAMPLE}_alignment_summary.txt | tail -1 | cut -f7
echo "  (Benchmark: >95%)"
echo
 
echo -n "Duplicate Rate: "
grep -A1 "LIBRARY" ${SAMPLE}_duplicate_metrics.txt | tail -1 | cut -f9
echo "  (Benchmark: <30%)"
echo
 
echo -n "Mean Insert Size: "
grep -A1 "MEDIAN_INSERT_SIZE" ${SAMPLE}_insert_size_metrics.txt | tail -1 | cut -f1
echo "bp  (Benchmark: 300-500bp)"
echo
 
echo "=== VARIANT CALLING QUALITY ==="
echo -n "Total SNPs: "
cat ${SAMPLE}_snp_count.txt
echo "  (Benchmark: 4-5 million)"
echo
 
echo -n "Total Indels: "
cat ${SAMPLE}_indel_count.txt
echo "  (Benchmark: 0.5-0.8 million)"
echo
 
echo -n "Ti/Tv Ratio: "
# Extract Ti/Tv ratio from bcftools stats output
grep -v "^#" ${SAMPLE}_variant_stats.txt | grep "TSTV" | cut -f5
echo "  (Benchmark: 2.0-2.1)"
echo
 
echo "For detailed variant annotation statistics, open:"
echo "${SAMPLE}_annotation_stats.html"
echo "========================================="