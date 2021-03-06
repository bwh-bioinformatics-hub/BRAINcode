# Script to discover variations from input BAM file
# author: Dong Xianjun
# Date: 2016-03-16
# Version: 1.0
# Usage: bsub _bam2vcf.sh accepted_hits.sam
# Input: accepted_hits.sam file from tophat (with Reads group info)
# Output: accepted_hits_GATK_SNPs.vcf
# Note: the intermidiate file starting with gatk_xxxx can be deleted later.

gatk_path=$HOME/neurogen/pipeline/RNAseq/bin/gatk
GENOME=/data/neurogen/referenceGenome/Homo_sapiens/UCSC/hg19

input_samfile=$1  # take input as sam file

echo "# change MQ:255 to 4 (or any number other than 255); required by GATK"
awk '{if ($5==255)$5=4; FQS="\t"; print}' accepted_hits.sam > gatk_accepted_hits.sam

echo "# sam --> bam"
samtools view -Sb gatk_accepted_hits.sam -o gatk_accepted_hits.bam

# add bam index:  (added after mark duplicate)
samtools index gatk_accepted_hits.bam

echo "# mark duplicate of bam file"
java -Xmx40g -jar $gatk_path/MarkDuplicates.jar INPUT=gatk_accepted_hits.bam OUTPUT=gatk_accepted_hits_marked.bam METRICS_FILE=gatk_metrics.txt CREATE_INDEX=true VALIDATION_STRINGENCY=LENIENT REMOVE_DUPLICATES=true

echo "# Indel realign"
#realignerTargetCreator
java -Xmx40g -jar $gatk_path/GenomeAnalysisTK.jar -T RealignerTargetCreator -U ALLOW_N_CIGAR_READS -R $GENOME/Sequence/WholeGenomeFasta/genome.fa -I gatk_accepted_hits_marked.bam -o gatk_indel.intervals -known $GENOME/Annotation/Variation/Mills_and_1000G_gold_standard.indels.hg19.vcf 
echo "# IndelRealigner"
java -Xmx40g -jar $gatk_path/GenomeAnalysisTK.jar -T IndelRealigner -R $GENOME/Sequence/WholeGenomeFasta/genome.fa -I gatk_accepted_hits_marked.bam -targetIntervals gatk_indel.intervals -U ALLOW_N_CIGAR_READS -known $GENOME/Annotation/Variation/Mills_and_1000G_gold_standard.indels.hg19.vcf -o gatk_accepted_hits_marked_indelrealigned.bam

echo "## [optional] add read group and sort "
####java -Xmx40g -jar /PHShome/sj750/projects/convert_bam/AddOrReplaceReadGroups.jar INPUT=indelrealigned_accpeted_hits_100_marked.bam OUTPUT=indelrealigned_accpeted_rg_hits_100_marked.bam RGPL=illumina RGPU=1 RGLB=bar RGSM=march2013111 RGID=foo

echo "#index bam file"
samtools index gatk_accepted_hits_marked_indelrealigned.bam

echo "#BaseRecalibrator"
java -Xmx40g -jar $gatk_path/GenomeAnalysisTK.jar -T BaseRecalibrator -U ALLOW_N_CIGAR_READS -R $GENOME/Sequence/WholeGenomeFasta/genome.fa -I gatk_accepted_hits_marked_indelrealigned.bam -knownSites $GENOME/Annotation/Variation/dbsnp_138.hg19.vcf -o gatk_recal_data.table
echo "#Print reads"
java -Xmx40g -jar $gatk_path/GenomeAnalysisTK.jar -T PrintReads -U ALLOW_N_CIGAR_READS -R $GENOME/Sequence/WholeGenomeFasta/genome.fa -I gatk_accepted_hits_marked_indelrealigned.bam -BQSR gatk_recal_data.table -o gatk_accepted_hits_marked_indelrealigned_BQSR.bam

echo "##HaplotypeCaller(after BQSR)"
# only extract SNPs in the exon regions
##java -Xmx40g -jar $PATH/gatk/GenomeAnalysisTK.jar -T HaplotypeCaller -R $GENOME/Sequence/WholeGenomeFasta/genome.fa --filter_reads_with_N_cigar -I gatk_accepted_hits_marked_indelrealigned_BQSR.bam -o gatk_accepted_hits_BQSR.vcf -D $GENOME/Annotation/Variation/dbsnp_138.hg19.vcf -stand_call_conf 50.0 -stand_emit_conf 10.0 -L $GENOME/Annotation/Genes/gencode.v13.annotation.gtf.exons.bed
# all SNPs
java -Xmx40g -jar $gatk_path/GenomeAnalysisTK.jar -T HaplotypeCaller -R $GENOME/Sequence/WholeGenomeFasta/genome.fa -U ALLOW_N_CIGAR_READS -I gatk_accepted_hits_marked_indelrealigned_BQSR.bam -o gatk_accepted_hits_BQSR.vcf -D $GENOME/Annotation/Variation/dbsnp_138.hg19.vcf -stand_call_conf 50.0 -stand_emit_conf 10.0

## VQSR:
echo "# Recalibration"
java -Xmx40g -jar $gatk_path/GenomeAnalysisTK.jar -T VariantRecalibrator -R $GENOME/Sequence/WholeGenomeFasta/genome.fa --input gatk_accepted_hits_BQSR.vcf --maxGaussians 2 --numBadVariants 3000 -resource:hapmap,known=false,training=true,truth=true,prior=15.0 $GENOME/Annotation/Variation/hapmap_3.3.hg19.vcf -resource:omni,known=false,training=true,truth=true,prior=12.0 $GENOME/Annotation/Variation/1000G_omni2.5.hg19.vcf -resource:1000G,known=false,training=true,truth=false,prior=10.0 $GENOME/Annotation/Variation/1000G_phase1.snps.high_confidence.hg19.vcf -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $GENOME/Annotation/Variation/dbsnp_138.hg19.vcf -an DP -an QD -an FS -an MQRankSum -an ReadPosRankSum -mode SNP -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 -recalFile gatk_recalibrate.SNP.recal -tranchesFile gatk_recalibrate.SNP.tranches -rscriptFile gatk_recalibrate.SNP.plots.R
echo "#Apply the desired level of recalibration to the SNPs in the call set"
java -Xmx40g -jar $gatk_path/GenomeAnalysisTK.jar -T ApplyRecalibration -R $GENOME/Sequence/WholeGenomeFasta/genome.fa --input gatk_accepted_hits_BQSR.vcf -mode SNP --ts_filter_level 99.0 -recalFile gatk_recalibrate.SNP.recal -tranchesFile gatk_recalibrate.SNP.tranches -o accepted_hits_GATK_SNPs.vcf

# remove intermediate files
rm gatk_*


#vcf2table

awk 'BEGIN {OFS = "\t"} /^##/ {next} /^#/ {sub(/^#/,"",$1)} {$1=$1; print}' accepted_hits_GATK_SNPs.vcf > table

sed 's/:/ /g' table > head.table

awk '{if((length($4)==1) && (length($5)==1) && ($7="PASS")&&($16>15)) print $1, $2, $3, $4, $5, $14, $16}' head.table > GT_DP_head_GATK.table



## TODO:
# 1. generatet a summary table for this sample, with one row and N columns (N=number of SNPs found in this sample) with SNP ID in the header 

echo "GATK done!"
