#!/bin/bash
###########################################
# script to combine bigwig, using trimmed mean of unionBedGraphs for samples from the same group
# Usage: $0 HC_SNDA
# bsub -J HC_SN -q normal -n 4 -M 6000 _combine_bigwig.sh HC_SN
# for i in HCILB_SNDA HC_PY HC_nonNeuron HC_Neuron HC_MCPY HC_TCPY HC_SNDA ILB_SNDA HC_PBMC HC_FB PD_SNDA HC_SNDAstranded; do echo $i; bsub -J $i -q normal -n 4 -M 6000 _combine_bigwig.sh $i; done
# Author: Xianjun Dong
# Version: 1.0
# Date: 2014-Oct-22
###########################################
#!/bin/bash

list_bw_file=$1
group_lable=$2

N=`wc -l $list_bw_file`
echo "N = $N"

# the nuclear genome size:
# curl -s http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.chrom.sizes | grep -v "_" | grep -v chrM | awk '{s+=$2}END{print s}'  # 3095677412
GENOME_SIZE=3095677412

if [ "$N" == "1" ]
then
  awk -v GENOME_SIZE=$GENOME_SIZE '{OFS="\t";S+=$4*($3-$2); if(id!=$4 || e!=$2 || chr!=$1) {if(chr!="") print chr,s,e,id; chr=$1;s=$2;e=$3;id=$4;} else {e=$3;}}END{print chr,s,e,id; TOTAL=GENOME_SIZE; bc=S/TOTAL;print "#basalCoverage="bc, "#"S"/"TOTAL;}' `sed 's/bw/bedGraph/g' $list_bw_file` > trimmedmean.uniq.normalized.$group_lable.bedGraph
  ln -fs `cut -f2 $list_bw_file` trimmedmean.uniq.normalized.$group_lable.bw
  exit
fi
    
echo "["`date`"] computing trimmed mean of bedGraph"
#-------------------
unionBedGraphs -i `cut -f2 $list_bw_file | sed 's/bw/bedGraph/g'` \
| awk -v GENOME_SIZE=$GENOME_SIZE 'function trimmedMean(v, p) {c=asort(v,j); a=int(c*p); sum=0; for(i=a+1;i<=(c-a);i++) sum+=j[i];return sum/(c-2*a);} {OFS="\t"; n=1; for(i=4;i<=NF;i++) S[n++]=$i; tm=trimmedMean(S, 0.1); if(tm!=0) print $1,$2,$3,tm; s+=tm*($3-$2);}END{TOTAL=GENOME_SIZE; bc=s/TOTAL; print "#basalCoverage="bc, "#"s"/"TOTAL;}' \
| awk '{OFS="\t"; if(id!=$4 || e!=$2 || chr!=$1) {if(chr!="") print chr,s,e,id; chr=$1;s=$2;e=$3;id=$4;} else {e=$3;}}END{print chr,s,e,id}' > trimmedmean.uniq.normalized.$group_lable.bedGraph

echo "["`date`"] bedgraph --> bigwig"
#-------------------
bedGraphToBigWig trimmedmean.uniq.normalized.$group_lable.bedGraph $GENOME/Annotation/Genes/ChromInfo.txt trimmedmean.uniq.normalized.$group_lable.bw

echo "["`date`"] Done!"