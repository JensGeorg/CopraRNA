#!/usr/bin/env perl

use strict;
use warnings;
use Cwd 'abs_path'; ## edit 2.0.5.1

# get absolute path
my $ABS_PATH = abs_path($0); ## edit 2.0.5.1
# remove script name at the end
# match all non slash characters at the end of the string
$ABS_PATH =~ s|[^/]+$||g; ## edit 2.0.5.1
my $PATH_COPRA_SUBSCRIPTS = $ABS_PATH;

my $ncrnas = $ARGV[0]; # input_sRNA.fa
my $upfromstartpos = $ARGV[1]; # 200
my $down = $ARGV[2]; # 100
my $mrnapart = $ARGV[3]; # cds or 5utr or 3utr
my $GenBankFiles = "";
my $orgcount = 0;

my $cores = `grep 'core count:' CopraRNA_option_file.txt | grep -oP '\\d+'`; ## edit 2.0.4
chomp $cores; ## edit 2.0.4

# check if CopraRNA2 prediction should be made
my $cop2 = `grep 'CopraRNA2:' CopraRNA_option_file.txt | sed 's/CopraRNA2://g'`; ## edit 2.0.5.1
chomp $cop2;

# check for verbose printing
my $verbose = `grep 'verbose:' CopraRNA_option_file.txt | sed 's/verbose://g'`; ## edit 2.0.5.1
chomp $verbose;

# get amount of top predictions to return
my $top_count = `grep 'top count:' CopraRNA_option_file.txt | grep -oP '\\d+'`; ## edit 2.0.5.1
chomp $top_count;
$top_count++; # need this to include the header

# check for websrv output printing
my $websrv = `grep 'websrv:' CopraRNA_option_file.txt | sed 's/websrv://g'`; ## edit 2.0.5.1
chomp $websrv;

# get window size option
my $winsize = `grep 'win size:' CopraRNA_option_file.txt | sed 's/win size://g'`; ## edit 2.0.5.1
chomp $winsize;

# get maximum base pair distance 
my $maxbpdist = `grep 'max bp dist:' CopraRNA_option_file.txt | sed 's/max bp dist://g'`; ## edit 2.0.5.1
chomp $maxbpdist;

open ERRORLOG, ">>err.log" or die("\nError: cannot open file err.log in homology_intaRNA.pl\n\n"); ## edit 2.0.2 

my $tripletorefseqnewfile = $PATH_COPRA_SUBSCRIPTS . "kegg2refseqnew.csv";
my %refseqaffiliations = ();

open(MYDATA, $tripletorefseqnewfile) or die("\nError: cannot open file $tripletorefseqnewfile in homology_intaRNA.pl\n\n");
    my @triptorefseqnew = <MYDATA>;
close MYDATA;

foreach(@triptorefseqnew) {
    my @split = split("\t", $_);
    my @split2 = split(" ", $split[1]);
    foreach(@split2) {
        chomp $split[1];#these are refseqids
        $refseqaffiliations{$_} = $split[1];
    }
}

# add "ncRNA_" to fasta headers
system "sed 's/>/>ncRNA_/g' $ncrnas > ncrna.fa"; ## edit 2.0.5.1 // replaced put_ncRNA_fasta_together.pl with this statement
# override $ncrnas variable
$ncrnas = "ncrna.fa";

# get Orgcount
$orgcount = (scalar(@ARGV) - 4);

## prepare input for combine_clusters.pl
## Download Refseq files by Refseq ID 
my $RefSeqIDs = `grep ">" input_sRNA.fa | tr '\n' ' ' | sed 's/>//g'`; ## edit 2.0.5.1
my @split_RefIds = split(/\s+/, $RefSeqIDs);

foreach(@split_RefIds) {
    my $currRefSeqID = $_;

    my $presplitreplicons = $refseqaffiliations{$currRefSeqID};
    my @replikons = split(/\s/, $presplitreplicons); # added this
    
    foreach(@replikons) {
        my $refseqoutputfile = $_ . ".gb"; # added .gb
        $GenBankFiles = $GenBankFiles . $refseqoutputfile . ",";
        my $accessionnumber = $_;
        system "cp /data/db/databases/refseq_gbk_bacteria/04-05-2016/$accessionnumber.gb $accessionnumber.gb" if (-e "/data/db/databases/refseq_gbk_bacteria/04-05-2016/$accessionnumber.gb"); ## edit 2.0.3 ## edit 2.0.3.2 changed .gbk to .gb because ending was changed in local mirror
        print $PATH_COPRA_SUBSCRIPTS  . "get_refseq_from_refid.pl -acc $accessionnumber -g $accessionnumber.gb \n" if ($verbose); ## edit 1.2.1 ## edit 2.0.2
        system $PATH_COPRA_SUBSCRIPTS . "get_refseq_from_refid.pl -acc $accessionnumber -g $accessionnumber.gb"; ## edit 1.2.1 ## edit 2.0.2
    }
    chop $GenBankFiles;
    $GenBankFiles = $GenBankFiles . " ";
}

## RefSeq correct download check for 2nd try ## edit 1.2.5
my @files = ();
@files = <*gb>;

foreach(@files) {
    open(GBDATA, $_) or die("\nError: cannot open file $_ in homology_intaRNA.pl\n\n");
        my @gblines = <GBDATA>;
    close GBDATA;

    my $lastLine = $gblines[-2]; ## edit 2.0.2
    my $lastLine_new = $gblines[-1]; ## edit 2.0.3, because of new file donwload the bottom differs
    if ($lastLine =~ m/^\/\//) {
        # all is good
    } elsif ($lastLine_new =~ m/^\/\//) {
        # all is good
    } else {
        system "rm $_"; # remove file to try download again later
    }
}

## refseq availability check
@files = ();

my @totalrefseqFiles = split(/\s|,/, $GenBankFiles);
my $consistencyswitch = 1;

my $limitloops = 0;

my $sleeptimer = 30; ## edit 1.2.0
while($consistencyswitch) {
    @files = ();
    @files = <*gb>;
    foreach(@totalrefseqFiles) {
        chomp $_;
        my $value = $_;
        if(grep( /^$value$/, @files )) { $consistencyswitch = 0;
        } else {
             $limitloops++;
             $consistencyswitch = 1;
 
             if($limitloops > 50) { $consistencyswitch = 0; }
             my $refOut = $_;
             my $accNr = $_;
             chop $accNr;
             chop $accNr;
             chop $accNr;
             sleep $sleeptimer; ## edit 1.2.0
             $sleeptimer = $sleeptimer * 1.1; ## edit 1.2.0
             print "next try: " . $PATH_COPRA_SUBSCRIPTS . "get_refseq_from_refid.pl -acc $accNr -g $accNr.gb\n" if ($verbose); ## edit 1.2.0 ## edit 1.2.1 ## edit 2.0.2
             system $PATH_COPRA_SUBSCRIPTS . "get_refseq_from_refid.pl -acc $accNr -g $accNr.gb"; ## edit 1.2.1 ## edit 2.0.2
             last;
        }
    }
}

### end availability check


### refseq correct DL check kill job ## edit 1.2.5
@files = <*gb>;

foreach(@files) {
    open(GBDATA, $_) or die("\nError: cannot open file $_ in homology_intaRNA.pl\n\n");
        my @gblines = <GBDATA>;
    close GBDATA;

    my $lastLine = $gblines[-2]; ## edit 2.0.2
    my $lastLine_new = $gblines[-1]; ## edit 2.0.3, because of new file donwload the bottom differs
    if ($lastLine =~ m/^\/\//) {
        # all is good
    } elsif ($lastLine_new =~ m/^\/\//) {
        # all is good
    } else {
        print ERRORLOG "File $_ did not download correctly. This is probably due to a connectivity issue on your or the NCBI's side. Please try to resubmit your job later (~2h.).\n"; # kill ## edit 2.0.2
    }
}


## fixing issue with CONTIG and ORIGIN both in gbk file (can't parse without this) ## edit 1.2.4

@files = <*gb>;

foreach (@files) {
    system "sed -i '/^CONTIG/d' $_"; ## d stands for delete
}

#### end quickfix

## edit 1.2.2 adding new exception check
@files = <*gb>;

foreach (@files) {
    system $PATH_COPRA_SUBSCRIPTS . "check_for_gene_CDS_features.pl $_ >> gene_CDS_exception.txt";
}

open(MYDATA, "gene_CDS_exception.txt") or die("\nError: cannot open file gene_CDS_exception.txt at homology_intaRNA.pl\n\n");
    my @exception_lines = <MYDATA>;
close MYDATA;


if (scalar(@exception_lines) >= 1) {
    my $exceptionRefSeqs = "";
    foreach(@exception_lines) {
        my @split = split(/\s+/,$_);
        $exceptionRefSeqs = $exceptionRefSeqs . $split[-1] . " ";
    }
    print ERRORLOG "Error: gene but no CDS features present in $exceptionRefSeqs.\n This is most likely connected to currently corrupted RefSeq record(s) at the NCBI.\nPlease resubmit your job without the currently errorous organism(s) or wait some time with your resubmission.\nUsually the files are fixed within ~1 week.\n"; ## edit 1.2.2 added \n ## edit 2.0.2
}
## end CDS gene exception check


## get cluster.tab with DomClust
unless (-e "cluster.tab") { # only do if cluter.tab has not been imported ## edit 2.0.4 changed this to -e

    ### get AA fasta for homolog clustering

    @files = <*gb>;

    foreach(@files) {
        system $PATH_COPRA_SUBSCRIPTS . "get_CDS_from_gbk.pl $_ >> all.fas"; ## edit 2.0.5.1 // removed unless 
    }

    # prep for DomClust
    system "formatdb -i all.fas" unless (-e "all.fas.blast"); ## edit 2.0.1
    system "blastall -a $cores -p blastp -d all.fas -e 0.001 -i all.fas -Y 1e9 -v 30000 -b 30000 -m 8 -o all.fas.blast 2> /dev/null" unless (-e "all.fas.blast"); # change the -a parameter to qdjust core usage ## edit 2.0.1 // ## edit 2.0.5.1 // added 2> /dev/null to prevent output to the terminal
    system $PATH_COPRA_SUBSCRIPTS . "blast2homfile.pl all.fas.blast > all.fas.hom"; ## edit 2.0.5.1 // removed -distconv this is now fixed within the script
    system $PATH_COPRA_SUBSCRIPTS . "fasta2genefile.pl all.fas";
    # DomClust
    system $PATH_COPRA_SUBSCRIPTS . "DomClust/domclust/bin-Linux/domclust all.fas.hom all.fas.gene -HO -S -c60 -p0.5 -V0.6 -C80 -o5 > cluster.tab";

    # edit 2.0.2
    system "grep '>' all.fas | uniq -d > N_chars_in_CDS.txt";
    if (-s "N_chars_in_CDS.txt") {
        print ERRORLOG "'N' characters found in nucleotide CDS. Please remove organism(s) with locus tags:\n";
        system "cat err.log N_chars_in_CDS.txt > err.log.tmp";
        system "mv err.log.tmp err.log";
    }

}

# 16s sequence parsing 
print $PATH_COPRA_SUBSCRIPTS . "parse_16s_from_gbk.pl $GenBankFiles > 16s_sequences.fa\n" if ($verbose);
system $PATH_COPRA_SUBSCRIPTS . "parse_16s_from_gbk.pl $GenBankFiles > 16s_sequences.fa";

# check 16s
open(MYDATA, "16s_sequences.fa") or die("\nError: cannot open file 16s_sequences.fa in homology_intaRNA.pl\n\n");
    my @sixteenSseqs = <MYDATA>;
close MYDATA;

my $sixteenScounter = 0;
my $temp_16s_ID = ""; ## edit 2.0.2
foreach (@sixteenSseqs) {
    if ($_ =~ m/>/) {
        $temp_16s_ID = $_; ## edit 2.0.2
        chomp $temp_16s_ID; ## edit 2.0.2
        $sixteenScounter++;
    } else {
        if ($_ =~ m/N/) { print ERRORLOG "\nError: 'N' characters present in 16s_sequences.fa. Remove $temp_16s_ID from the input for the job to execute correctly.\n"; } ## edit 2.0.2
    }
}

if ($sixteenScounter ne $orgcount) {
    my $no16sOrgs = `(grep ">" 16s_sequences.fa && grep ">" input_sRNA.fa) | sort | uniq -u | tr '\n' ' '`; ## edit 2.0.3
    chomp $no16sOrgs; ## edit 2.0.3
    print ERRORLOG "\nError: wrong number of sequences in 16s_sequences.fa.\nOne (or more) of your entered organisms does not contain a correctly annotated 16s rRNA sequence and needs to be removed.\nPlease remove $no16sOrgs\n"; ## edit 2.0.2 
}

## prepare single organism whole genome target predictions 
system "echo $GenBankFiles > merged_refseq_ids.txt"; ## edit 2.0.2 # need this for iterative region plot construction

print $PATH_COPRA_SUBSCRIPTS . "prepare_intarna_out.pl $ncrnas $upfromstartpos $down $mrnapart $GenBankFiles\n" if ($verbose);
system $PATH_COPRA_SUBSCRIPTS . "prepare_intarna_out.pl $ncrnas $upfromstartpos $down $mrnapart $GenBankFiles";
## end  edit 2.0.0

# do CopraRNA combination 
## edit 2.0.4 // removed all N*final.csv files as input to combine_clusters.pl
print $PATH_COPRA_SUBSCRIPTS . "combine_clusters.pl $orgcount\n" if ($verbose);
system $PATH_COPRA_SUBSCRIPTS . "combine_clusters.pl $orgcount";

# make annotations
system $PATH_COPRA_SUBSCRIPTS . "get_genname_genid_note_from_gbk_opt.pl CopraRNA1_with_pvsample_sorted.csv $GenBankFiles > CopraRNA1_anno.csv"; ## edit 2.0.4 -> opt // ## edit 2.0.5.1
system $PATH_COPRA_SUBSCRIPTS . "get_genname_genid_note_from_gbk_opt.pl CopraRNA2_no_pvsample_sorted.csv $GenBankFiles > CopraRNA2_anno.csv" if ($cop2); ## edit 2.0.4 -> opt // ## edit 2.0.5.1 

# get additional homologs in cluster.tab
system $PATH_COPRA_SUBSCRIPTS . "parse_homologs_from_domclust_table.pl CopraRNA1_anno.csv cluster.tab > CopraRNA1_anno_addhomologs.csv"; ## edit 2.0.5.1
system $PATH_COPRA_SUBSCRIPTS . "parse_homologs_from_domclust_table.pl CopraRNA2_anno.csv cluster.tab > CopraRNA2_anno_addhomologs.csv" if ($cop2); ## edit 2.0.5.1

# add corrected p-values (padj) - first column
system "awk -F',' '{ print \$1 }' CopraRNA1_anno_addhomologs.csv > CopraRNA1_pvalues.txt"; ## edit 2.0.5.1
system "awk -F',' '{ print \$1 }' CopraRNA2_anno_addhomologs.csv > CopraRNA2_pvalues.txt" if ($cop2); ## edit 2.0.5.1

system "R --slave -f $PATH_COPRA_SUBSCRIPTS/calc_padj.R --args CopraRNA1_pvalues.txt";
system "paste padj.csv CopraRNA1_anno_addhomologs.csv -d ',' > CopraRNA1_anno_addhomologs_padj.csv";

if ($cop2) {
    system "R --slave -f $PATH_COPRA_SUBSCRIPTS/calc_padj.R --args CopraRNA2_pvalues.txt";
    system "paste padj.csv CopraRNA2_anno_addhomologs.csv -d ',' > CopraRNA2_anno_addhomologs_padj.csv";
}

# add amount sampled values CopraRNA 1 // CopraRNA 2 has no sampling
system $PATH_COPRA_SUBSCRIPTS . "get_amount_sampled_values_and_add_to_table.pl CopraRNA1_anno_addhomologs_padj.csv 0 > CopraRNA1_anno_addhomologs_padj_amountsamp.csv"; ## edit 2.0.5.1
system $PATH_COPRA_SUBSCRIPTS . "get_amount_sampled_values_and_add_to_table.pl CopraRNA2_anno_addhomologs_padj.csv 1 > CopraRNA2_anno_addhomologs_padj_amountsamp.csv" if ($cop2); ## edit 2.0.5.1

# truncate final output // ## edit 2.0.5.1
system "head -n $top_count CopraRNA1_anno_addhomologs_padj_amountsamp.csv > CopraRNA1_final.csv";
system "head -n $top_count CopraRNA2_anno_addhomologs_padj_amountsamp.csv > CopraRNA2_final.csv" if ($cop2);

##### create regions plots
## system "R --slave -f " . $PATH_COPRA_SUBSCRIPTS . "script_R_plots_6.R --args CopraRNA1_final_all.csv 2> /dev/null > /dev/null"; ## edit 2.0.5.1 // changed input file and piping command line output to /dev/null for silencing

##### convert postscript files to PNG

# thumbnails
## system "convert -size 170x170 -resize 170x170 -flatten -rotate 90 sRNA_regions.ps thumbnail_sRNA.png";
## system "convert -size 170x170 -resize 170x170 -flatten -rotate 90 mRNA_regions.ps thumbnail_mRNA.png";

# blow up images
## system "convert -density '300' -resize '700' -flatten -rotate 90 sRNA_regions.ps sRNA_regions.png";
## system "convert -density '300' -resize '700' -flatten -rotate 90 mRNA_regions.ps mRNA_regions.png";

# check for fail CopraRNA 1
open(MYDATA, "CopraRNA1_anno_addhomologs_padj_amountsamp.csv") or die("\nError: cannot open file CopraRNA1_anno_addhomologs_padj_amountsamp.csv at homology_intaRNA.pl\n\n");
    my @CopraRNA_out_lines = <MYDATA>;
close MYDATA;

if (scalar(@CopraRNA_out_lines) <= 1) {
    print ERRORLOG "Error: CopraRNA1 run failed.\n"; ## edit 2.0.2
}

if ($websrv) { # only if webserver output is requested via -websrv ## edit 2.0.5.1

    my $allrefs = $refseqaffiliations{$ARGV[4]};
    my @splitallrefs = split(/\s/,$allrefs);

    my $themainrefid = $splitallrefs[0]; # organism of interest RefSeq ID
    my $orgofintTargets = $themainrefid . "_upfromstartpos_" . $upfromstartpos . "_down_" . $down . ".fa";
    my $orgofintsRNA = "ncRNA_" . $themainrefid . ".fa";

    # returns comma separated locus tags (first is always refseq ID). Example: NC_000913,b0681,b1737,b1048,b4175,b0526,b1093,b1951,,b3831,b3133,b0886,,b3176 
    my $top_predictons_locus_tags_c1 = `awk -F',' '{print \$3}' CopraRNA1_final.csv | sed 's/(.*)//g' | tr '\n' ','`;
    my $top_predictons_locus_tags_c2 = `awk -F',' '{print \$3}' CopraRNA2_final.csv | sed 's/(.*)//g' | tr '\n' ','` if ($cop2);

    # split
    my @split_c1 = split(/,/, $top_predictons_locus_tags_c1);
    my @split_c2 = split(/,/, $top_predictons_locus_tags_c2) if ($cop2);
    
    # remove RefSeqID
    shift @split_c1;
    shift @split_c2 if ($cop2);

    foreach (@split_c1) {
        if ($_) {
            system "grep -A1 '$_' $orgofintTargets >> CopraRNA1_top_targets.fa";
        }
    }

    if ($cop2) {
        foreach (@split_c2) {
            if ($_) {
                system "grep -A1 '$_' $orgofintTargets >> CopraRNA2_top_targets.fa";
            }
        }
    }
    
    system "IntaRNA_1ui.pl -t CopraRNA1_top_targets.fa -m $orgofintsRNA -o -w $winsize -L $maxbpdist > Cop1_IntaRNA1_ui.intarna";
    # fix for ambiguous nt in intarna output
    system "sed -i '/contains ambiguous IUPAC nucleotide encodings/d' Cop1_IntaRNA1_ui.intarna";
    system "IntaRNA_1ui.pl -t CopraRNA2_top_targets.fa -m $orgofintsRNA -o -w $winsize -L $maxbpdist > Cop2_IntaRNA1_ui.intarna" if ($cop2);
    # fix for ambiguous nt in intarna output
    system "sed -i '/contains ambiguous IUPAC nucleotide encodings/d' Cop2_IntaRNA1_ui.intarna" if ($cop2);

    system $PATH_COPRA_SUBSCRIPTS . "prepare_output_for_websrv_new.pl CopraRNA1_final.csv Cop1_IntaRNA1_ui.intarna";
    system "mv coprarna_internal_table.csv coprarna1_websrv_table.csv";
    system $PATH_COPRA_SUBSCRIPTS . "prepare_output_for_websrv_new.pl CopraRNA2_final.csv Cop2_IntaRNA1_ui.intarna" if ($cop2);
    system "mv coprarna_internal_table.csv coprarna2_websrv_table.csv" if ($cop2);

    system "cp $orgofintTargets target_sequences_orgofint.fa";
}

system $PATH_COPRA_SUBSCRIPTS . "print_archive_README.pl > README.txt";

die(); #### remove this later

##### create DAVID enrichment table

## this has all been changed to python in version 2.0.3.1 because the DAVID-WS perl client was flawed
system "/usr/bin/python2.7 " . $PATH_COPRA_SUBSCRIPTS . "DAVIDWebService_CopraRNA.py CopraRNA_result_all.csv > DAVID_enrichment_temp.txt"; ## edit 2.0.3.1
system "grep -P 'termName\\s=|categoryName\\s=|score\\s=|listHits\\s=|percent\\s=|ease\\s=|geneIds\\s=|listTotals\\s=|popHits\\s=|popTotals\\s=|foldEnrichment\\s=|bonferroni\\s=|benjamini\\s=|afdr\\s=' DAVID_enrichment_temp.txt | sed 's/\\s//g' > DAVID_enrichment_grepped_temp.txt"; ## edit 2.0.3.1
system $PATH_COPRA_SUBSCRIPTS . "make_enrichment_table_from_py_output.pl DAVID_enrichment_grepped_temp.txt > termClusterReport.txt"; ## edit 2.0.3.1

open(MYDATA, "termClusterReport.txt") or system "echo 'If you are reading this, then your prediction did not return an enrichment, your organism of interest is not in the DAVID database\nor the DAVID webservice is/was termporarily down. You can either rerun your CopraRNA\nprediction or create your enrichment manually at the DAVID homepage.' > termClusterReport.txt";
    my @enrichment_lines = <MYDATA>;
close MYDATA;

unless($enrichment_lines[0]) {
    system "echo -e 'If you are reading this, then your prediction did not return an enrichment, your organism of interest is not in the DAVID database\nor the DAVID webservice is/was termporarily down. You can either rerun your CopraRNA\nprediction or create your enrichment manually at the DAVID homepage.' > termClusterReport.txt";
}

##### end DAVID enrichment

#############################

## add enrichment visualization ## edit 1.2.5

system "cp $PATH_COPRA_SUBSCRIPTS" . "copra_heatmap.html ."; ## edit 1.2.5 ## edit 1.2.7 (edited html file)
system "/usr/local/R/2.15.1-lx/bin/R --slave -f " . $PATH_COPRA_SUBSCRIPTS . "extract_functional_enriched.R"; ## edit 1.2.5 ## edit 1.2.7 (edited R code)
system $PATH_COPRA_SUBSCRIPTS . "make_heatmap_json.pl enrichment.txt"; ##edit 1.2.5
system "cp $PATH_COPRA_SUBSCRIPTS" . "index-thumb.html ."; ## edit 1.2.5
system "cp $PATH_COPRA_SUBSCRIPTS" . "index-pdf.html ."; ## edit 1.2.6
system $PATH_COPRA_SUBSCRIPTS . "phantomjs " . $PATH_COPRA_SUBSCRIPTS . "rasterize.js " . "./index-thumb.html enriched_heatmap_big.png"; ## edit 1.2.5
system $PATH_COPRA_SUBSCRIPTS . "phantomjs " . $PATH_COPRA_SUBSCRIPTS . "rasterize.js " . "./index-pdf.html enriched_heatmap_big.pdf"; ## edit 1.2.6
system "rm index-thumb.html"; ## edit 1.2.5
system "rm index-pdf.html"; ## edit 1.2.6

## end add enrichment vis

system "rm enrichment.txt"; # edit 1.2.5
system "rm gene_CDS_exception.txt"; ## edit 1.2.2
system "rm CopraRNA_pvalues.txt";
system "rm final_uniq.csv";
system "rm dndout";
# fix warning "rm: missing operand Try 'rm --help' for more information." ## edit 2.0.1
my $temp_fasta_check = `find -regex ".*fa[0-9]+\$"`;
if ($temp_fasta_check) {
    system 'find -regex ".*fa[0-9]+$" | xargs rm';
}
system "rm padj.csv";
system "rm formatdb.log" if (-e "formatdb.log");
system "rm all.fas.gene" if (-e "all.fas.gene");
system "rm all.fas.hom" if (-e "all.fas.hom");
system "rm all.fas.tit" if (-e "all.fas.tit");
system "rm all.fas.phr" if (-e "all.fas.phr");
system "rm all.fas.pin" if (-e "all.fas.pin");
system "rm all.fas.psq" if (-e "all.fas.psq");
system "rm error.log" if (-e "error.log");

close ERRORLOG;
