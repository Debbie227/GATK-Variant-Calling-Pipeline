#!/usr/bin/env nextflow


workflow {

    reads_ch = Channel.of([params.sample, params.bam])

    reads_ch | MARK_DUPLICATES | BQSR | VARIANT_CALL

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

    label 'big mem'

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
