#!/usr/bin/env bash
set -e
# Author: Muhammad Elhossary - elhossary@zbmed.de
WORKING_DIR="$@"
main(){
	# Decalre array of target organisms directories
	for organism_DIR in "${WORKING_DIR}";
	do
		set_variables "${organism_DIR}" # DO NOT comment this function call.
		update_chromosomes_sizes_file
		create_ref_genome_track
		create_annotation_tracks
		download_wigToBigWig_tool
		#convert_wig_to_bigwig
		#create_bigwig_track
		generate_names
		#zip_datasource
	done
}
set_variables(){
	BIN_DIR=../bin
	DATASOURCES_POOL_DIR=.
	ORGANISM_DATASOURCE_DIR="${DATASOURCES_POOL_DIR}/${1}"
	INPUT_DIR="${ORGANISM_DATASOURCE_DIR}/raw_data"
	REFSEQ_DIR="${INPUT_DIR}/reference_sequence"
	ANNOTATIONS_DIR="${INPUT_DIR}/annotations"
	WIGGLE_DIR="${INPUT_DIR}/coverage/wiggle"
	BIGWIG_DIR="${INPUT_DIR}/coverage/bigwig"
	CHROM_SIZES_FILE="${DATASOURCES_POOL_DIR}/all.chrom.sizes"
}
update_chromosomes_sizes_file(){
	echo "Updating chromosomes sizes file"
	for file_name in "${REFSEQ_DIR}"/*.*; do
		# Get all chromosomes sizes
		cat "${file_name}" | cut -d' ' -f 1 | awk '$0 ~ ">" {if (NR > 1) {print c;} c=0;printf substr($0,2,100) "\t"; } $0 !~ ">" {c+=length($0);} END { print c; }' >> "${CHROM_SIZES_FILE}"
		# Remove duplicates if found
		sort < "${CHROM_SIZES_FILE}" | uniq > "${CHROM_SIZES_FILE}~" && mv "${CHROM_SIZES_FILE}~" "${CHROM_SIZES_FILE}"
	done
}
create_ref_genome_track(){
	echo "Preparing reference genome track for: ${ORGANISM_DATASOURCE_DIR}"
	for file_name in "${REFSEQ_DIR}"/*.fa; do
		"${BIN_DIR}"/prepare-refseqs.pl \
		--fasta "${file_name}" \
		--out "${ORGANISM_DATASOURCE_DIR}"/
	done
}
create_annotation_tracks(){
	#remove genes those have more than one part as they cause errors that prevent the whole creation
	#Special case for ecoli gff file
	#sed -i "s/.*;part=.*//g" #other command
	#sed -i '/^$/d' #other command
	#sed -i "s/.*pseudogene.*//g" "${file_name}"
	#sed -i "s/.*ID=cds-gnl.*//g" "${file_name}"
	#sed -i '/^$/d' "${file_name}"
	echo "Preparing annotation tracks for: ${ORGANISM_DATASOURCE_DIR}"
	for file_name in "${ANNOTATIONS_DIR}"/*.gff; do
		sed --in-place -e "s/;Parent=.*//g" "${file_name}"
		"${BIN_DIR}"/flatfile-to-json.pl --trackLabel "${file_name##*/}" \
		--trackType HTMLFeatures \
		--gff "${file_name}" \
		--out "${ORGANISM_DATASOURCE_DIR}"/
	done
}cat "${file_name}" | cut -d' ' -f 1 | awk '$0 ~ ">" {if (NR > 1) {print c;} c=0;printf substr($0,2,100) "\t"; } $0 !~ ">" {c+=length($0);} END { print c; }' >> "${CHROM_SIZES_FILE}"
download_wigToBigWig_tool(){
	echo "Downloading tool wigToBigWig"
	wget -P "${BIN_DIR}" \
		http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/wigToBigWig
	chmod u+x "${BIN_DIR}"/wigToBigWig

}
convert_wig_to_bigwig(){
	echo "converting wig to bigwig for: ${ORGANISM_DATASOURCE_DIR}"
	for FILES in "${WIGGLE_DIR}"/*.wig
	do
		"${BIN_DIR}"/wigToBigWig "$FILES" ./all.chrom.sizes"${BIGWIG_DIR}"/$(basename "$FILES" .wig).bw
	done
}
create_bigwig_track(){
	echo "Preparing bigwig track for: ${ORGANISM_DATASOURCE_DIR}"
	for BIGWIG in "${BIGWIG_DIR}"/*.bw
	do
		"${BIN_DIR}"/add-bw-track.pl --plot --in "${ORGANISM_DATASOURCE_DIR}"/trackList.json --label $(basename "$BIGWIG" .bw) --bw_url ../"$BIGWIG"
	done
}
generate_names(){
	echo "Generating names for: ${ORGANISM_DATASOURCE_DIR}"
	"${BIN_DIR}"/generate-names.pl --out "${ORGANISM_DATASOURCE_DIR}"/ --completionLimit 20

}
zip_datasource(){
	echo "Zipping for: ${ORGANISM_DATASOURCE_DIR}"
	zip -r "${ORGANISM_DATASOURCE_DIR}.zip" "${ORGANISM_DATASOURCE_DIR}"
}
main
