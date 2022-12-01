export PATH=$PATH:/home/project/hisat2-2.2.1/
export PATH=$PATH:/home/project/stringtie-2.1.5.Linux_x86_64
export PATH=$PATH:/home/project/hg38/
export PATH=$PATH:/home/project/hg38_tran/
export PATH=$PATH:/home/project/gffcompare-0.12.2.Linux_x86_64
ref="Homo_sapiens_assembly19.fasta"
ref_ann="Homo_sapiens.GRCh38.84.gtf"
GTF1="/home/project/datas/GTF1"
GENE_ABUN="/home/project/datas/"
COV_REF="/home/project/datas/"

mkdir BAM
mkdir $GTF1

while read -r url1 sex
do
	oldIFS="$IFS"
	#trim reads
	url2="${url1/_2.fastq.gz/_1.fastq.gz}"
	wget "$url1"
	wget "$url2"
	#wget $url2 
	#mv $url1 $READS_HOME/
	#mv $url2 $READS_HOME/
	IFS='/'
	read -ra newarr <<< "${url1}"
#	IFS='/'
	read -ra newarr2 <<< "${url2}"

	oldname1=${newarr[-1]}
	oldname2=${newarr2[-1]}
	name1="${sex}_${oldname1}"
	name2="${sex}_${oldname2}"
	echo "$sex"
	echo "$name1"
	echo "$name2"
	#0 preprocess reads
	java -jar trimmomatic-0.39.jar PE "$oldname1" "$oldname2" "$name1"_output_forward_paired.fq.gz "$name1"_output_forward_unpaired.fq.gz "$name1"_output_reverse_paired.fq.gz "$name1"_output_reverse_unpaired.fq.gz ILLUMINACLIP:./adapters/TruSeq3-PE.fa:2:30:10:2:keepBothReads LEADING:3 TRAILING:3 MINLEN:36
	# not sure how to get from step 0 to step 1 -> 
	# need to define $f1 - the basename of name1 and name2
	#1. map reads and sort the output
	#using index built with annotation in mind
	hisat2 -p 8 --dta -x Homo_sapiens_assembly19 -1 "$name1"_output_forward_paired.fq.gz -2 "$name1"_output_reverse_paired.fq.gz -S $name1'.tran.sam' 
	echo 'samtools' 
	#conver to bam
	samtools sort -@ 8 -o $name1'.tran.bam' $name1'.tran.sam'
	mv $name1'.tran.bam' BAM/
	#2.
	#run StringTie to assemble the read alignments obtained in the previous step;
	#it is recommended to run StringTie with the -G option if the reference annotation is available.
	echo 'stringtie'
	echo "${GTF1}/${name1}.guided.gtf" 
	stringtie -p 8 -l $name1 "BAM/${name1}.tran.bam" -G $ref_ann -o "${GTF1}/${name1}.guided.gtf" -A "${GENE_ABUN}/${name1}.gene_abund.tab" -C "${COV_REF}/${name1}.cov_refs.gtf" > "${GTF1}/${name1}.log"
	stringtie -p 8 -eB -G "${GTF1}/${name1}.guided.gtf" "BAM/${name1}.tran.bam" -o  "${GTF1}/${name1}.guided.abundancies.gtf"
	gffcompare "${GTF1}/${name1}.guided.gtf" -r $ref_ann -s $ref -p "${GTF1}/${name1}.guided"
	mv gffcmp.annotated.gtf "${name1}.annotated.gtf"
	mv gffcmp.loci "${GTF1}/${name1}.loci"
	mv gffcmp.stats "${GTF1}/${name1}.stats"
	mv gffcmp.tracking "${GTF1}/${name1}.tracking"
	rm *.sam
	IFS="$oldIFS"
done < "datas/input.txt"


#list.s must contain files for discover.

echo 'collect gtf'
ls "$GTF1"/*.gtf  > gtf_list.txt
ls "$GTF1"/M*.gtf > gtf_male_list.txt
ls "$GTF1"/F*.gtf > gtf_female_list.txt

#example
#stringtie --merge -p 8 -G chrX_data/genes/chrX.gtf -o stringtie_merged.gtf chrX_data/mergelist.txt

echo 'stringtie merge'
stringtie  --merge  -G $ref_ann -p 8 -o all_transcripts_strigtie_merged.gtf gtf_list.txt
stringtie  --merge  -G $ref_ann -p 8 -o females_merged.gtf gtf_female_list.txt
stringtie  --merge  -G $ref_ann -p 8 -o males_merged.gtf gtf_male_list.txt

# check out the transcripts
cat all_transcripts_strigtie_merged.gtf | head

# how many transcripts?
cat all_transcripts_strigtie_merged.gtf  | grep -v "^#" | awk '$3=="transcript" {print}' | wc -l

#for each RNA-Seq sample, run StringTie using the -B/-b and -e options in order to estimate 
#transcript abundances and generate read coverage tables for 
#$GTF1/ballgown. The -e option is not required but recommended for this run in order to produce more accurate 
#abundance estimations of the input transcripts. Each 
#StringTie run in this step will take as input the sorted read alignments 
#(BAM file) obtained in step 1 for the corresponding sample and the -G option with the 
#merged transcripts (GTF file) generated by stringtie --merge in step 3.
#Please note that this is the only case where the -G option is not used with a reference 
#annotation, but with the global, merged set of transcripts as observed across all samples.
# (This step is the equivalent of the Tablemaker step described in the 
#original $GTF1/ballgown pipeline.)

mkdir "${GTF1}/ballgown"
mkdir "${GTF1}/ballgown/ALL"
mkdir "${GTF1}/ballgown/F"
mkdir "${GTF1}/ballgown/M"

#prepare for $GTF1/ballgown
while read -r url1 sex
do
	oldIFS="$IFS"
	#wget $url2 
	#mv $url1 $READS_HOME/
	#mv $url2 $READS_HOME/
	IFS='/'
	read -ra newarr <<< "$url1"
	f1="${sex}_${newarr[-1]}"
	IFS="$oldIFS"
	mkdir "${GTF1}/ballgown/ALL/${f1}"
	mkdir "${GTF1}/ballgown/F/${f1}"
	mkdir "${GTF1}/ballgown/M/${f1}"
	
	echo 'all'
	stringtie -e -B -p 8 -G all_transcripts_strigtie_merged.gtf -o "${GTF1}/ballgown/${f1}.all.gtf" "BAM/${f1}.tran.bam"
	mv $GTF1'/ballgown/'*.ctab "${GTF1}/ballgown/ALL/${f1}"
	mv "${GTF1}/ballgown/${f1}.all.gtf" "${GTF1}/ballgown/ALL/${f1}"

	echo 'females'
	stringtie -e -B -p 8 -G females_merged.gtf -o "${GTF1}/ballgown/${f1}.females.gtf" "BAM/${f1}.tran.bam"
	mv $GTF1'/ballgown/'*.ctab "${GTF1}/ballgown/F/${f1}"
	mv "${GTF1}/ballgown/${f1}.females.gtf"  "${GTF1}/ballgown/F/${f1}"

	echo 'males'
	stringtie -e -B -p 8 -G males_merged.gtf -o "${GTF1}/ballgown/${f1}.males.gtf"   "BAM/${f1}.tran.bam"
	mv $GTF1'/ballgown/'*.ctab "${GTF1}/ballgown/M/${f1}"
	mv "${GTF1}/ballgown/${f1}.males.gtf" "${GTF1}/ballgown/M/${f1}"
	echo "${GTF1}/ballgown/*ctab"
	echo "${GTF1}/ballgown/M/${f1}"

#fi

done < 'datas/input.txt'
