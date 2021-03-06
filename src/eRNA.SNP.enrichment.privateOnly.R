# The Fisher exact test was performed to test the odds ratio of trait association with enhancers vs non-enhancers taking into account the genomic distribution of SNPs.  
# OR = (A/B) / (C/D), where
# 
# A: number of trait-associated SNPs in enhancers
# B: number of non-trait-associated SNPs in enhancers (from dbSNP - GWAS SNPs for that trait)
# C: number of trait-associated SNPs distal to enhancers
# D: number of non-trait-associated SNPs distal to enhancers (from dbSNP - GWAS SNPs for that trait)

args<-commandArgs(TRUE)
type=args[1]
minor=args[2]

require(ggplot2)

setwd('~/eRNAseq')

s=read.table(paste0("SNP.private.",minor,".counts.summary"), header=F,row.names=1); 
results=data.frame();
if(minor=="major") celltypes=c('HCILB_SNDA','HC_PY','HC_nonNeuron')
if(minor=="minor") celltypes=c('HCILB_SNDA','HC_TCPY','HC_MCPY','HC_PBMC','HC_FB')

for(i in celltypes){
  n1=s[i,1]; n2=s['all',1];
  all=read.table(paste0(i,"/SNP.",type,".count.all")); rownames(all)=all[,1]
  x=read.table(paste0(i,"/SNP.",type,".count.private.",minor,".HTNE")); rownames(x)=x[,1]
  df=cbind(x, all[rownames(x),2]); df=df[,-1]; colnames(df)=c('observed','all')
  results=rbind(results, cbind(Disease_or_Trait=rownames(df), 
                               df, 
                               pvalue=apply(df, 1, function(x) fisher.test(matrix(c(x[1],x[2]-x[1], n1-x[1], n2-n1-x[2]+x[1]), nrow = 2), alternative='greater')$p.value), 
                               OR=apply(df, 1, function(x) fisher.test(matrix(c(x[1],x[2]-x[1], n1-x[1], n2-n1-x[2]+x[1]), nrow = 2), alternative='greater')$estimate), 
                               type=i))
  results$Disease_or_Trait = as.character(results$Disease_or_Trait)
}

results=subset(results, OR>1 & pvalue<0.01 & observed>3)
table(results$type)
#   HTNE    exons promoter   random 
#     82       12       70       2 
results$Disease_or_Trait=gsub("_"," ", results$Disease_or_Trait)

results = results[with(results, order(type, -OR)), ]
write.table(results, paste0("eRNA.private.",minor,".SNP.enrichments.",type,".xls"), sep="\t", col.names = T, row.names = F)

pdf(paste0("eRNA.private.",minor,".SNP.enrichments.",type,".pdf"), width=24, height=12); 
# Note: Don't use ggsave() with Rscript, which will generate another Rplot.pdf unnecessarily. See http://stackoverflow.com/questions/19382384/ggplot2-overwrite-one-another-in-rplots-pdf

# re-order the levels in the order of appearance in the data.frame
results$Disease_or_Trait2 <- factor(results$Disease_or_Trait, unique(as.character(results$Disease_or_Trait)))
p = ggplot(results, aes(x=Disease_or_Trait2, y=OR, fill=type, ymax=max(OR)*1.1)) 
p = p + geom_bar(width=.2, position = position_dodge(width=1), stat="identity") 
p = p + theme_bw() 
p = p + theme(axis.title.x=element_blank(), axis.text.x = element_text(angle = 90, vjust=0.5, hjust = 1, size=8), legend.justification=c(1,1), legend.position=c(1,1)) 
p = p + geom_text(aes(label=paste0(observed," (",round(-log10(pvalue),1),")")), position = position_dodge(width=1), hjust=0, vjust=.5, angle = 90, size=2.5) 
p = p + ggtitle(paste0("private HTNE -- SNP enrichments (LD from ",type,", sorted by OR)")) 

print(p);

results = results[with(results, order(type, pvalue)), ]
results$Disease_or_Trait2 <- factor(results$Disease_or_Trait, unique(as.character(results$Disease_or_Trait)))
p = ggplot(results, aes(x=Disease_or_Trait2, y=-log10(pvalue), fill=type, ymax=max(-log10(pvalue))*1.1)) 
p = p + geom_bar(width=.2, position = position_dodge(width=1), stat="identity") 
p = p + geom_hline(yintercept=-log10(0.05/1037), size=1)  ## Bonferroni correction, where 1037 is the number of disease/traits in GWAS (wc -l SNP.$type.count.all)
p = p + theme_bw() 
p = p + theme(axis.title.x=element_blank(), axis.text.x = element_text(angle = 90, vjust=0.5, hjust = 1, size=8), legend.justification=c(1,1), legend.position=c(1,1)) 
p = p + geom_text(aes(label=paste0(observed," (",round(OR,1),")")), position = position_dodge(width=1), hjust=0, vjust=.5, angle = 90, size=2.5) 
p = p + ggtitle(paste0("private HTNE -- SNP enrichments (LD from ",type,", sorted by pvalue)")) 

print(p);

dev.off()
