#!/usr/bin/env nextflow


workflow {

    reads_ch = Channel.of([params.sample, params.bam])

    reads_ch | MARK_DUPLICATES | BQSR | VARIANT_CALL | RECAL_SNP

}


process MARK_DUPLICATES {

    label 'small_mem'

    input:
    tuple val (sample), path (bam)

    output:
    tuple val(sample), 
    path("${sample}_marked.bam"),
    path("${sample}_marked.bai")

    script:
    """
    gatk MarkDuplicates \
  -I $bam \
  -O ${sample}_marked.bam \
  -M metrics.txt \
  --CREATE_INDEX true
    """
}

process BQSR {

    label 'small_mem'

    input:
    tuple val(sample), path(r1)

    output:
    tuple val(sample), 
    path("${sample}_recal.bam"), 
    path("${sample}_recal.bai")

    script:
    """
  gatk BaseRecalibrator \
    -I $r1 \
    -R ${params.ref} \
    --known-sites ${params.mills} \
    --known-sites ${params.dbsnp} \
    -O recal.table

gatk ApplyBQSR \
  -I $r1 \
  -R ${params.ref} \
  --bqsr-recal-file recal.table \
  -O ${sample}_recal.bam \
  --create-output-bam-index true
  """
}

process VARIANT_CALL {

    label 'big_mem'

    input:
    tuple val(sample),
    path(r1)

    output:
    tuple val(sample),
    path("${sample}.vcf.gz")

    script:
    """
    gatk HaplotypeCaller \
  -R ${params.ref} \
  -I $r1 \
  -O ${sample}.vcf.gz
}

process RECAL_SNP {

    label 'small_mem'

    input:
    tuple val(sample)
    path(r1)

    output:
    tuple val(sample)
    path(${sample}_snps.recal)
    path(${sample}_snps.tranches)

    script:
    """
    gatk VariantRecalibrator \
    -R ${params.ref} \
    -V $r1 \
    --resource:hapmap,known=false,training=true,truth=true,prior=15.0 \
        ${params.hapmap} \
    --resource:omni,known=false,training=true,truth=false,prior=12.0 \
        ${params.omni} \
    --resource:1000G,known=false,training=true,truth=false,prior=10.0 \
        ${params.g1000} \
    --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 \
        ${params.dbsnp} \  # Known variants (not for training)
    -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR \
    -mode SNP \
    -O ${sample}_snps.recal \
    --tranches-file ${sample}_snps.tranches
    """
}
