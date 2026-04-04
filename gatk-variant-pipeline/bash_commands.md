## Initial commands for GATK pipeline in codespaces and notes on runs and commands

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
cd ../..
cd reference

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
pixi run fastp -i data/raw/SRR12023503_1.fastq -I data/raw/SRR12023503_2.fastq \
  -o data/trimmed/SRR12023503_1.fastq -O data/trimmed/SRR12023503_2.fastq

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

pixi run fastp -i data/raw/SRR12023503_1.fastq.gz -I data/raw/SRR12023503_2.fastq.gz \
 -o data/trimmed/SRR12023503_1.fastq.gz -O data/trimmed/SRR12023503_2.fastq.gz

# fastp.html and fasp.json were properly made this time

pixi run fastqc data/trimmed/*.fastq.gz -o results/qc/trimmed
# paired reads no longer have data below the 20 quality mark
```

```bash
# Align the reads to the genome with bwa

pixi run bwa mem reference/genome.fasta data/trimmed/SRR12023503_1.fastq.gz data/trimmed/SRR12023503_2.fastq.gz \
 > results/aligned/SRR12023503.sam

# This step is a good point for a lunch break...and maybe a walk...and a nap... It takes a very long time to align all these sequences.
# The sam file is quite large - next time pipe directly to bam to not take up the space. | samtools sort -o SRR12023503.bam

# Apparently I committed part of the sam file somehow despite adding it to the gitignore and caused a huge mess...
# In the process of fixing it I deleted the entire sam file. Lets re-run the alignment straight to sorted bam using 8 threads to spped up the process and keep the file size down!

pixi run bwa mem -t 8 reference/genome.fasta data/trimmed/SRR12023503_1.fastq.gz data/trimmed/SRR12023503_2.fastq.gz \
 | pixi run samtools sort -@8 -o results/aligned/SRR12023503.bam - \
 && pixi run samtools index results/aligned/SRR12023503.bam

 # Ran bwa mem for several hours with no output

 pixi run bwa mem reference/genome.fasta data/trimmed/SRR12023503_1.fastq.gz data/trimmed/SRR12023503_2.fastq.gz \
 > results/aligned/SRR12023503.sam

 # produced sam file - Thinking back I think it took about a third of the time of the first run
 
 pixi run samtools view -Sb results/aligned/SRR12023503.sam > results/aligned/SRR12023503.bam
 # error: [E::aux_parse] Incomplete aux field - Did it time out when my screen went to sleep?

 # Starting pipeline from beginning since several steps ran into memory errors and there was weird incomplete fields
 # alignment + bam + bai still did not have output with piping and && commands

pixi run bwa mem \
    -t $8 \     # Use multiple CPU threads for faster processing
    -M \                # Mark shorter split hits as secondary (required for Picard compatibility)
    -R "@RG\tID:SRR12023503\tSM:SRR12023503\tPL:ILLUMINA\tLB:SRR12023503_lib" \  # Read group info (required for GATK)
    reference/genome.fasta \      # Reference genome file
    data/trimmed/SRR12023503_1.fastq.gz \  # Trimmed forward reads
    data/trimmed/SRR12023503_2.fastq.gz \  # Trimmed reverse reads
    | pixi run samtools sort -@ $8 -o results/aligned/SRR12023503.bam  # Sort reads by position

# samtools sort getting error that the bam file doesn't exist...of course it doesn't? I'm trying to create it. Problem with using pixi run?
# ran command without the final pipe and output redirected to > results/aligned/SRR12023503.sam

pixi run samtools sort -@ 8 results/aligned/SRR12023503.sam -o results/aligned/SRR12023503.bam

# Command gave no output and no errors

pixi run samtools view -Sb results/aligned/SRR12023503.sam > results/aligned/unsort_SRR12023503.bam

# This worked but I'm running out of room again...

pixi run samtools sort results/aligned/unsort_SRR12023503.bam -o results/aligned/SRR12023503.bam

# This looks like it's working but I ran out of room - the problem may be the 8 threads - deleting unsorted bam and trying the sam to sorted bam again
# Deleted raw fastq data to make more room for the sorted bam file

pixi run samtools sort results/aligned/SRR12023503.sam -o results/aligned/SRR12023503.bam

pixi run samtools index results/aligned/SRR12023503.bam

# Happy dance time!!! After three days of troubleshooting I finally have a bam and bai file!!!!

 # If I'm piping multiple command together problems may arise. If one command fails the pipe may still partially run. Use "set -euo pipefail" 
 # at the top of a script to stop the script from continuing after a fail. -e exit if command fails -u fail on unidentified variables
```
```bash
# Check alignment rate, coverage depth, mapping quality, duplicate rate, insert size distribution

pixi run samtools flagstat results/aligned/SRR12023503.bam > results/qc/trimmed/SRR12023503_align_stats.txt # alignment rate. For WGS should be 95%+ for exome should be 90%+
# What is it? https://samtools.org/what-information-does-samtools-flagstat-provide/

pixi run samtools depth results/aligned/SRR12023503.bam -o results/qc/trimmed/SRR12023503_depth.txt # coverage depth or use mosdepth, qualimap. Should be 30x wgs or 80+ for exome.
# What is it? https://samtools.org/what-does-the-samtools-depth-command-tell-us/

# Duplicates should be less than 30. Can use picard MarkDuplicates
pixi run gatk MarkDuplicates \
    -I results/aligned/SRR12023503.bam \
    -O results/aligned/SRR12023503_marked_duplicates.bam \
    -M results/aligned/SRR12023503_duplicate_metrics.txt \  # File containing duplication statistics
    --CREATE_INDEX true  # Automatically create BAM index

# insert size duplication use picard or qualimap. Size should be ~300
pixi run picard CollectInsertSizeMetrics \
      I=results/aligned/SRR12023503.bam \
      O=results/qc/trimmed/SRR12023503_insert_size_metrics.txt \
      H=results/qc/trimmed/SRR12023503_insert_size_histogram.pdf \
      M=0.5
# What is it? https://gatk.broadinstitute.org/hc/en-us/articles/21905022322587-CollectInsertSizeMetrics-Picard
# error: All data categories were discarded because they contained < 0.5 of the total aligned paired data.

# coverage I think looks great? But properly paired is only 4%??? Properly mapped is only 11%?

# Lets check the trimmed files that are left to see why they aren't paired?
# Fastq-paired only works on non-zip files - validatefastq gives metrics
# picard and validatefastq are not compatible -need different versions of jdk
# fastq_utils has fastq_filterpair to sort and pair the files

pixi run fastq_filterpair \
    data/trimmed/SRR12023503_1.fastq.gz data/trimmed/SRR12023503_2.fastq.gz \
    data/trimmed/match_SRR12023503_1.fastq.gz data/trimmed/match_SRR12023503_2.fastq.gz \
    data/trimmed/SRR12023503_single.fastq.gz

# ran out of room again...deleted mark duplicates files to make room

# Files had many unpaired reads. Don't know if this was an issue with trimming or original file?? Now have almost 17mil paired reads.
# Recording 163437 unpaired reads from data/trimmed/SRR12023503_1.fastq.gz
# 100000Unpaired from data/trimmed/SRR12023503_1.fastq.gz: 163437
# Unpaired from data/trimmed/SRR12023503_2.fastq.gz: 163437
# Paired: 16829740


# This means I'm going to have to re-align the genome. Again.
# I guess I'll continue to assume that the chr 22 genome I have is hg38 and correct...I don't have space to download the human genome.

pixi run bwa mem \
    -M \
    -R "@RG\tID:SRR12023503\tSM:SRR12023503\tPL:ILLUMINA\tLB:SRR12023503_lib" \
    reference/genome.fasta \
    data/trimmed/match_SRR12023503_1.fastq.gz \
    data/trimmed/match_SRR12023503_2.fastq.gz \
    > results/aligned/SRR12023503.sam

#start 1:08pm
# Still lots of "skip orientation as there are not enough pairs" messages
# might be normal to have that? 

zcat data/trimmed/match_SRR12023503_1.fastq.gz | head -4

# @SRR12023503.1 1 length=101
# TGGGGTCTTGGTCCAGAAGGCCAATCTCCTGGCAGCCCACGCAGCACGTTCGAGAAATCTCACTTGTGGCGGGGTTCCAAACTGTTTCCATGCAGCCCCTT
# +SRR12023503.1 1 length=101
# CCCFFDDFHHHHHJJJJFGIJIHIIIIJJJJEHIJIIIIJEIGIIIJECCHGGHEHHHHEDFFFFEEECDDD#############################

# Header does not have /1 and /2 to specify that they are paired
# Did fastp break the headers? 

# Since all the large files at the beginning were deleted lets start all over again \o/ Cancelled run at 2:14
# This time try trim galore and check headers before moving on...

cat SRR12023503_1.fastq | head -8

# nope fastp didn't change the headers. They come @SRR12023503.1 1 length=101 in both files.

pixi run trim_galore \
    --paired \           # Indicates we have paired-end reads (R1 and R2)
    --quality 20 \       # Remove bases with quality score < 20
    --length 50 \        # Discard reads shorter than 50bp after trimming
    --output_dir data/trimmed/ \
    data/raw/SRR12023503_1.fastq.gz \
    data/raw/SRR12023503_2.fastq.gz

# ended with error: Read 2 output is truncated at sequence count: 18723539, please check your paired-end input files! Terminating...
# Lets run a quality check on paired files first then re-run trim galore

pixi run fastq_filterpair \
    data/raw/SRR12023503_1.fastq.gz data/raw/SRR12023503_2.fastq.gz \
    data/raw/match_SRR12023503_1.fastq.gz data/raw/match_SRR12023503_2.fastq.gz \
    data/raw/SRR12023503_single.fastq.gz

# Found 188126 unpaired reads

pixi run fastqc data/raw/match*.fastq.gz -o results/qc/raw

# QC looks about the same as original

pixi run trim_galore \
    --paired \
    --quality 20 \
    --length 50 \
    --fastqc \
    --fastqc_args "--outdir results/qc/trimmed/" \
    --output_dir data/trimmed/ \
    data/raw/match_SRR12023503_1.fastq.gz \
    data/raw/match_SRR12023503_2.fastq.gz

# No errors this time!
# QC looks good. per base sequence count is the only thing that failed.
# Time to align again

# Added command to run in paired mode
pixi run bwa mem \
    -t $8 \
    -M \
    -P \
    -R "@RG\tID:SRR12023503\tSM:SRR12023503\tPL:ILLUMINA\tLB:SRR12023503_lib" \
    reference/genome.fasta \
    data/trimmed/match_SRR12023503_1_val_1.fq.gz \
    data/trimmed/match_SRR12023503_2_val_2.fq.gz \
    > results/aligned/SRR12023503.sam

# Started at 3:45p
# Deleted all data in raw folder to make room
# Still has skip orentation errors...Hopefully qc will look better. 
# finished at 8:44p

pixi run samtools sort results/aligned/SRR12023503.sam -o results/aligned/SRR12023503.bam

pixi run samtools index results/aligned/SRR12023503.bam

pixi run samtools flagstat results/aligned/SRR12023503.bam > results/qc/trimmed/SRR12023503_align_stats.txt

pixi run samtools depth results/aligned/SRR12023503.bam -o results/qc/trimmed/SRR12023503_depth.txt

pixi run picard CollectInsertSizeMetrics \
    -I results/aligned/SRR12023503.bam \
    -O results/qc/trimmed/SRR12023503_insert_size_metrics.txt \
    -H results/qc/trimmed/SRR12023503_insert_size_histogram.pdf \
    -M 0.5

# Now 0% properly paired and 9% mapped? Not sure what the alignment stats really mean.
# Coverage depth seems to be above 80
# Collection size inserts still failed

# Likely a problem with the reference genome used. Still not sure where it came from or how much of chr 22 it covers
# Don't have the space to download a real genome so let's continue as is!
```

```bash
pixi run gatk MarkDuplicates \
    -I results/aligned/SRR12023503.bam \
    -O results/aligned/SRR12023503_marked_duplicates.bam \
    -M results/aligned/SRR12023503_duplicate_metrics.txt \
    --CREATE_INDEX true

pixi run gatk BaseRecalibrator \
    -I results/aligned/SRR12023503.bam \
    -R reference/genome.fasta \
    --known-sites reference/mills_and_1000G.indels.vcf.gz \
    --known-sites reference/dbsnp_146.hg38.vcf.gz \ 
    -O results/aligned/SRR12023503_recal_data.table
 
pixi run gatk ApplyBQSR \
    -I results/aligned/SRR12023503_marked_duplicates.bam \
    -R reference/genome.fasta \
    --bqsr-recal-file results/aligned/SRR12023503_recal_data.table \
    -O results/aligned/SRR12023503_recalibrated.bam


# What is BSQR? https://gatk.broadinstitute.org/hc/en-us/articles/360035890531-Base-Quality-Score-Recalibration-BQSR
# These steps are very fast! It doesn't look like many variant spots were found...
```

```bash
# Use GATK alignment summary to check final alignment
pixi run gatk CollectAlignmentSummaryMetrics \
    -R reference/genome.fasta \
    -I results/aligned/SRR12023503_recalibrated.bam \
    -O results/aligned/SRR12023503_alignment_summary.txt


    ```

```bash
# Use HaplotypeCaller to find raw variants
pixi run gatk HaplotypeCaller \
    -R reference/genome.fasta \
    -I results/aligned/SRR12023503_recalibrated.bam \
    -O results/aligned/SRR12023503.g.vcf.gz \
    -ERC GVCF \          # Emit Reference Confidence mode - creates GVCF format
    --dbsnp reference/dbsnp_146.hg38.vcf.gz  # Annotate with known variants

# GVCF mode records information about ALL sites (variant and non-variant)
# What is a gvcf? https://gatk.broadinstitute.org/hc/en-us/articles/360035531812-GVCF-Genomic-Variant-Call-Format
# Used for family studies or population studies

# Change GVCF to normal vcf
pixi run gatk GenotypeGVCFs \
    -R reference/genome.fasta \
    -V results/aligned/SRR12023503.g.vcf.gz \
    -O results/aligned/SRR12023503_raw_variants.vcf.gz
```

```bash
Variant Quality Score Recalibration
# Completely out of storage data for the month on codespaces with two weeks to go
# Trying Google shell cloud and google cloud storage.
```

```bash
# First download actual refence genome and GATK resource bundle with known variants
# Actually these already exist on GCS and can be accessed directly
gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta # accesses directly
# Created bucket on AWS
# BWA is not compatible with google storage so the alignment must be done locally. There wont be enough room. Have $300 credit so lets try?

#Create variables
Project_ID=gatk-resources-490700
Bucket=gatk-resource-bucket
Sample=SRR12023503
```
```bash
# Install pixi on GCP
mkdir -p data/raw
cd data/raw
curl -fsSL https://pixi.sh/install.sh | bash
source ~/.bashrc
pixi install
```
```bash
# Download raw data
pixi run fasterq-dump -p $Sample --split-files
# disk-limit exeeded! To see limits: re-run with '-x' option.
pixi run fasterq-dump -x -p $Sample --split-files
# mem-limit    : 52,428,800 bytes
# has a size of 1,797,147,729 bytes
# Money doesn't solve all problems

# Let's try to run the alignment in a docker container and send it to my gcp bucket
docker pull biocontainers/bwa:v0.7.17_cv1
docker run -it --entrypoint /bin/bash biocontainers/bwa:v0.7.17_cv1
conda install bioconda::sra-tools
fasterq-dump -x -p SRR12023503 --split-files
#fasterq-dump command not found
prefetch SRR12023503 --max-size 10g
# connection failed

# Tried fastq-dump and the command was recognized, but didn't recognize flags
fastq-dump -x -p SRR12023503 --split-files
# Could not find flags for paired end reads - all combinations errored out
```
```bash
#New terminal try to fasterq-dump straight the gcp bucket
# Only works with curl...can't use fasterq-dump without downloading locally and copying
```
```bash
# New month new codespaces quota!!
# Still have trimmed and validated paired files as well as aligned bam files
# Deleting bam and bai files as well as reference files to use GATK bundle ref for alignment

pixi add gsutil

# Try to run bwa mem using remote reference genome
pixi run bwa mem \
    -t $8 \
    -M \
    -P \
    -R "@RG\tID:SRR12023503\tSM:SRR12023503\tPL:ILLUMINA\tLB:SRR12023503_lib" \
    gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta \
    data/trimmed/match_SRR12023503_1_val_1.fq.gz \
    data/trimmed/match_SRR12023503_2_val_2.fq.gz \
    > results/aligned/SRR12023503.sam

# error fail to locate the index files - was pretty sure bwa didn't support remote calls but worth a try.
# bwa index is needed to create all the index files and the files must be in the same folder. (.amb, .ann, .pac, .bwt, .sa)

# copy the GATK reference files with hg38 genome
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta ref/genome.fasta
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.fai ref/
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dict ref/

# The dict (sequence dictionary) and fai (fasta index) files could be generated instead of downloaded.
# samtools faidx reference.fasta
# gatk CreateSequenceDictionary -R reference.fasta

# It doesn't look like they are necessary for bwa? Not sure why it would need to be copied as GPT suggested.
# GATK uses both of these files in later processes
# Dict files get added to the header or BAM and SAM files for matching purposes throughout GATK - must be referenced in bwa mem then to create the sam file?


pixi run bwa index ref/genome.fasta
# looking at the documentation this is not the right command for the whole genome. Genomes over 2GB shouldn't use the standard algorithm
# cancelling run

pixi run bwa index -a bwtsw ref/genome.fasta
# Uses new algrithm for whole genome - default is the "is" algorithm

# There is no .sa file - process may have interrupted when the computer went to sleep.

```

```bash
# Added .fasta to gitignore
# Should have been doing git commits after each step - transfer size is now too big -COMMIT MORE OFTEN
# error send-pack: unexpected disconnect while reading sideband packet
# increase buffer limit to 3gb allow all these commits to go through - default buffer is 1mb - max size may be 5gb?
git config --global http.postBuffer 3147483648
# still didn't work
git reset HEAD~1 # undo last push
git add -p # split git add into smaller chunks - choose which chunks to commit and push at a time
# bwt and pac files were 1.5GB adding all index files to gitignore

# Need to get .sa file so lets try again
pixi run bwa index -a bwtsw ref/genome.fasta
# After another 40+ minutes I got to the step to make the sa file...20 minutes later it still isn't done...
# Finally finished properly! [main] Real time: 4175.644 sec; CPU: 3854.110 sec
# try alignment tomorrow
```
```bash
pixi run bwa mem \
    -t $8 \
    -M \
    -P \
    -R "@RG\tID:SRR12023503\tSM:SRR12023503\tPL:ILLUMINA\tLB:SRR12023503_lib" \
    ref/genome.fasta \
    data/trimmed/match_SRR12023503_1_val_1.fq.gz \
    data/trimmed/match_SRR12023503_2_val_2.fq.gz \
    > results/aligned/SRR12023503.sam

#Command stalls with no error message
# Could be memory issue
# renamed genome.fasta.fai and genome.dict to see if these files are not being found
# Issue remains

# removed the linux variable tag $ that was in front of the number of threads 
pixi run bwa mem \
    -t 8 \
    -M \
    -P \
    -R "@RG\tID:SRR12023503\tSM:SRR12023503\tPL:ILLUMINA\tLB:SRR12023503_lib" \
    ref/genome.fasta \
    data/trimmed/match_SRR12023503_1_val_1.fq.gz \
    data/trimmed/match_SRR12023503_2_val_2.fq.gz \
    > results/aligned/SRR12023503.sam

# Took a lot longer and still stalled out at the same place - just after [M::bwa_idx_load_from_disk] read 0 ALT contigs

# Maybe the bwa index did not complete properly again? Download files from gcp instead of trying index for another hour

pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.amb ref/genome.fasta.amb
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.ann ref/genome.fasta.ann
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.bwt ref/genome.fasta.bwt
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.pac ref/genome.fasta.pac
pixi run gsutil cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.sa ref/genome.fasta.sa
# Google recommends Gcloud storage cli over gsutil - look into this later

# New error! [bwt_restore_sa] SA-BWT inconsistency: seq_len is not the same. Abort!
# Different version of bwa for indexing and for mem
# Updated pixi toml - Try bwa 0.7.17 - not compatible reverted back to 19

```