# run the facets library

suppressPackageStartupMessages(library("optparse"));
suppressPackageStartupMessages(library("RColorBrewer"));
suppressPackageStartupMessages(library("plyr"));
suppressPackageStartupMessages(library("dplyr"));
suppressPackageStartupMessages(library("tidyr"));
suppressPackageStartupMessages(library("stringr"));
suppressPackageStartupMessages(library("magrittr"));
suppressPackageStartupMessages(library("facets"));
suppressPackageStartupMessages(library("foreach"));
#suppressPackageStartupMessages(library("Cairo"));

if (!interactive()) {
    options(warn = -1, error = quote({ traceback(); q('no', status = 1) }))
}

optList <- list(
	make_option("--seed", default = 1234),
	make_option("--snp_nbhd", default = 250, type = 'integer', help = "window size"),
	make_option("--minNDepth", default = 25, type = 'integer', help = "minimum depth in normal to keep the position"),
	make_option("--maxNDepth", default= 1000, type= 'integer', help = "maximum depth in normal to keep the position"),
	make_option("--pre_cval", default = NULL, type = 'integer', help = "pre-processing critical value"),
	make_option("--cval1", default = NULL, type = 'integer', help = "critical value for estimating diploid log Ratio"),
	make_option("--cval2", default = NULL, type = 'integer', help = "starting critical value for segmentation (increases by 25 until success)"),
	make_option("--max_cval", default = 5000, type = 'integer', help = "maximum critical value for segmentation (increases by 25 until success)"),
	make_option("--min_nhet", default = 25, type = 'integer', help = "minimum number of heterozygote snps in a segment used for bivariate t-statistic during clustering of segment"),
	make_option("--genome", default = 'b37', type = 'character', help = "genome of counts file"),
	make_option("--unmatched", default=FALSE, type=NULL,  help="is it unmatched?"),
	make_option("--minGC", default = 0, type = NULL, help = "min GC of position"),
	make_option("--maxGC", default = 1, type = NULL, help = "max GC of position"),
	make_option("--outPrefix", default = NULL, help = "output prefix"))

parser <- OptionParser(usage = "%prog [options] [tumor-normal base counts file]", option_list = optList);

arguments <- parse_args(parser, positional_arguments = T);
opt <- arguments$options;

if (length(arguments$args) < 1) {
    cat("Need base counts file\n")
    print_help(parser);
    stop();
} else if (is.null(opt$outPrefix)) {
    cat("Need output prefix\n")
    print_help(parser);
    stop();
} else {
    baseCountFile <- arguments$args[1];
}

tumorName <- baseCountFile %>% sub('.*/', '', .) %>% sub('_.*', '', .)
normalName <- baseCountFile %>% sub('.*/', '', .) %>% sub('.*_', '', .) %>% sub('\\..*', '', .)

switch(opt$genome,
	b37={gbuild="hg19"},
	b37_hbv_hcv={gbuild="hg19"},
	GRCh37={gbuild="hg19"},
	hg19={gbuild="hg19"},
	hg19_ionref={gbuild="hg19"},
	mm9={gbuild="mm9"},
	mm10={gbuild="mm10"},
	GRCm38={gbuild="mm10"},
	hg38={gbuild="hg38"},
       { stop(paste("Invalid Genome",opt$genome)) })

buildData=installed.packages()["facets",]
cat("#Module Info\n")
for(fi in c("Package","LibPath","Version","Built")){
    cat("#",paste(fi,":",sep=""),buildData[fi],"\n")
}
version=buildData["Version"]
cat("\n")

rcmat <- readSnpMatrix(gzfile(baseCountFile))
chromLevels=unique(rcmat[,1])
print(chromLevels)
if (gbuild %in% c("hg19", "hg18")) { chromLevels=intersect(chromLevels, c(1:22,"X"))
} else { chromLevels=intersect(chromLevels, c(1:19,"X"))}
print(chromLevels)

if(is.null(opt$cval1)) { stop("cval1 cannot be NULL")}
if(is.null(opt$pre_cval)) { opt$pre_cval = opt$cval1-50 }
if(is.null(opt$cval2)) { opt$cval2 = opt$cval1-50}

if (opt$minGC == 0 & opt$maxGC == 1) {
	preOut=preProcSample(rcmat, snp.nbhd = opt$snp_nbhd, ndepth = opt$minNDepth, cval = opt$pre_cval, 
		gbuild=gbuild, ndepthmax=opt$maxNDepth, unmatched=opt$unmatched)
} else {
    if (gbuild %in% c("hg19", "hg18"))
      	 nX <- 23
    if (gbuild %in% c("mm9", "mm10"))
	 nX <- 20
	pmat <- facets:::procSnps(rcmat, ndepth=opt$minNDepth, het.thresh = 0.25, snp.nbhd = opt$snp_nbhd, 
		gbuild=gbuild, unmatched=opt$unmatched, ndepthmax=opt$maxNDepth)
	dmat <- facets:::counts2logROR(pmat[pmat$rCountT > 0, ], gbuild, unmatched=opt$unmatched)
        dmat$keep[which(dmat$gcpct>=opt$maxGC | dmat$gcpct<=opt$minGC)] <- 0
	dmat <- dmat[dmat$keep == 1,]
	tmp <- facets:::segsnps(dmat, opt$pre_cval, hetscale=F)
	pmat$keep <- 0
	pmat$keep[which(paste(pmat$chrom, pmat$maploc, sep="_") %in% paste(dmat$chrom, dmat$maploc, sep="_"))] <- 1

	out <- list(pmat = pmat, gbuild=gbuild, nX=nX)
	preOut <- c(out,tmp)
}
### Used this instead of preProc for wes_hall_pe
#    if (gbuild %in% c("hg19", "hg18"))
#        nX <- 23
#    if (gbuild %in% c("mm9", "mm10"))
#        nX <- 20
#pmat <- facets:::procSnps(rcmat, ndepth=opt$minNDepth, het.thresh = 0.25, snp.nbhd = opt$snp_nbhd, gbuild=gbuild, unmatched=F, ndepthmax=opt$maxNDepth)
#pmat$keep[which(pmat$chrom==2 & pmat$maploc>=28641233 & pmat$maploc<=28691172)] <- 1
#pmat$keep[which(pmat$chrom==19 & pmat$maploc>=32757577 & pmat$maploc<=32826160)] <- 1
#dmat <- facets:::counts2logROR(pmat[pmat$rCountT > 0, ], gbuild, unmatched=F)
#tmp <- facets:::segsnps(dmat, opt$pre_cval, hetscale=F)
#out <- list(pmat = pmat, gbuild=gbuild, nX=nX)
#preOut <- c(out,tmp)


out1 <- preOut %>% procSample(cval = opt$cval1, min.nhet = opt$min_nhet)

cat ("Completed preProc and proc\n")
cat ("procSample FLAG is", out1$FLAG, "\n")

save(preOut, out1, file = str_c(opt$outPrefix, ".Rdata"), compress=T)

cval <- opt$cval2
success <- F
while (!success && cval < opt$max_cval) {
    out2 <- preOut %>% procSample(cval = cval, min.nhet = opt$min_nhet, dipLogR = out1$dipLogR)
    print(str_c("attempting to run emncf() with cval2 = ", cval))
    fit <- tryCatch({
        out2 %>% emcncf
    }, error = function(e) {
        print(paste("Error:", e))
        return(NULL)
    })
    if (!is.null(fit)) {
        success <- T
        cat ("emcncf was successful with cval", cval, "\n")
    } else {
        cval <- cval + 25
    }
}
if (!success) {
    stop("Failed to segment data\n")
} else { print ("Completed segmentation")}

formatSegmentOutput <- function(out,sampID) {
	seg=list()
	seg$ID=rep(sampID,nrow(out$out))
	seg$chrom=out$out$chr
	seg$loc.start=rep(NA,length(seg$ID))
	seg$loc.end=seg$loc.start
	seg$num.mark=out$out$num.mark
	seg$seg.mean=out$out$cnlr.median
	for(i in 1:nrow(out$out)) {
		lims=range(out$jointseg$maploc[(out$jointseg$chrom==out$out$chr[i] & out$jointseg$seg==out$out$seg[i])],na.rm=T)
		seg$loc.start[i]=lims[1]
		seg$loc.end[i]=lims[2]
	}	
	as.data.frame(seg)
}
id <- paste(tumorName, normalName, sep = '_')
out2$IGV = formatSegmentOutput(out2, id)
save(preOut, out1, out2, fit, file = str_c(opt$outPrefix, ".Rdata"), compress=T)

if(sum(out2$out$num.mark)<=10000) { height=4; width=7} else { height=6; width=9}
pdf(file = str_c(opt$outPrefix, ".cncf.pdf"), height = height, width = width)
plotSample(out2, fit)
dev.off()

source("usb-modules-v2/copy_number/runFacets_myplot.R")
if(sum(out2$out$num.mark)<=10000) { height=2.5; width=7} else { height=2.5; width=8}
pdf(file = str_c(opt$outPrefix, ".logR.pdf"), height = height, width = width)
myPlotFACETS(out2, fit, plot.type="logR")
dev.off()

write.table(fit$cncf, str_c(opt$outPrefix, ".cncf.txt"), row.names = F, quote = F, sep = '\t')

ff = str_c(opt$outPrefix, ".out")
cat("# Version =", version, "\n", file = ff, append = T)
cat("# Input =", basename(baseCountFile), "\n", file = ff, append = T)
cat("# tumor =", tumorName, "\n", file = ff, append = T)
cat("# normal =", normalName, "\n", file = ff, append = T)
cat("# snp.nbhd =", opt$snp_nbhd, "\n", file = ff, append = T)
cat("# cval1 =", opt$cval1, "\n", file = ff, append = T)
cat("# cval2 =", cval, "\n", file = ff, append = T)
cat("# min.nhet =", opt$min_nhet, "\n", file = ff, append = T)
cat("# genome =", opt$genome, "\n", file = ff, append = T)
cat("# Purity =", fit$purity, "\n", file = ff, append = T)
cat("# Ploidy =", fit$ploidy, "\n", file = ff, append = T)
cat("# dipLogR =", fit$dipLogR, "\n", file = ff, append = T)
cat("# dipt =", fit$dipt, "\n", file = ff, append = T)
cat("# loglik =", fit$loglik, "\n", file = ff, append = T)

warnings()

