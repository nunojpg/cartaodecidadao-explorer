#!/bin/bash
# Copyright (C) 2016-2017, Nuno Goncalves <nunojpg@gmail.com>

# trace and notepad objects are not validated by SOd
# document can not be authenticated (INTERNAL_AUTH/ICAO MRTD AA) because it requires mutual authentication with a government issued CVC

error=false

print_all_fields=false
print_photo_ascii=false
read_address=false
print_sod_values=false
do_online_OCSP=true

fn_opensc_cardsearch="opensc_cardsearch"
fn_obj_data="object_citizen_data"
fn_obj_address="object_citizen_address"
fn_SOd="object_SOd"
fn_SOd_cert="doc_sign_cert"
fn_photo_jp2="photo.jp2"
fn_photo_bmp="photo.bmp"
fn_photo_jpg="photo.jpg"

pin_tries_left() {
	pins_list="$1"
	pin="$2"
	tries="${pins_list##*"$pin"}"
	tries="${tries#*Tries left*: }"
	echo "${tries:0:1}"
}

remove_file() {
	[ -a "$1" ]&& rm "$1"
}

check_package() {
	which "${1}" > /dev/null && return
cat << EOF
Can't find "${1}".
Please install it. Eg. in Ubuntu type:
sudo apt install "${2}"
EOF
	exit 1
}

show_help() {
cat << EOF
Usage: ${0##*/} [-habcp]
CARTAO DE CIDADAO EXPLORER
Read, cryptographically authenticate data, and print it.

    -h          display this help and exit
    -a		Print all identification fields
    -b		Print address
    -c          Disable OCSP (online) verification
    -p		Print photo ascii art
    -s		Print SOd values
EOF
}

while getopts "hpabcs" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
	a)  print_all_fields=true
            ;;
	b)  read_address=true
            ;;
	c)  do_online_OCSP=false
	    ;;
        p)  print_photo_ascii=true
            ;;
	s)  print_sod_values=true
            ;;        
        '?')
            show_help >&2
            exit 1
            ;;
    esac
done

check_package "pkcs15-tool" "opensc"

pins_list="$(pkcs15-tool --wait --verbose --list-pins 2> >(tee $fn_opensc_cardsearch >&2))"

cardsearch="$(<$fn_opensc_cardsearch)"
rm $fn_opensc_cardsearch
if [[ "$cardsearch" != *Found\ CARTAO\ DE\ CIDADAO! ]]; then exit; fi

driver="${pins_list#*driver }"
echo "${driver%%.*}"

auth="$(pin_tries_left "$pins_list" "Auth PIN")"
sign="$(pin_tries_left "$pins_list" "Sign PIN")"
address="$(pin_tries_left "$pins_list" "Address PIN")"

printf '\nPIN tries left            : [AUTH: %s] [SIGN: %s] [Address: %s]\n' "$auth" "$sign" "$address"

remove_file "$fn_obj_data"
remove_file "$fn_obj_address"
remove_file "$fn_SOd"
remove_file "$fn_SOd_cert"
remove_file "$fn_photo_jp2"
remove_file "$fn_photo_bmp"

mkdir -p cache
pkcs15-tool --read-data-object 'Citizen Data' --output "cache/$fn_obj_data" > /dev/null 2>&1  || { echo "UNABLE TO RETRIEVE Citizen Data"; exit 1; }
if $read_address ; then
	echo #new line
	pkcs15-tool --read-data-object 'Citizen Address Data' --output "cache/$fn_obj_address"  || { echo "UNABLE TO RETRIEVE Address"; exit 1; }
	echo #new line
fi
pkcs15-tool --read-data-object 'SOd' --output "cache/$fn_SOd" > /dev/null 2>&1  || { echo "UNABLE TO RETRIEVE SOd"; exit 1; }

# read ID data
fields_data=(
        IssuingEntity
	Country
	DocumentType
	DocumentNumber
	DocumentNumberPAN
	DocumentVersion
	ValidityBeginDate
	LocalofRequest
	ValidityEndDate
	Surname
	Name
	Gender
	Nacionality
	DateOfBirth
	Height
	CivilianIdNumber
	SurnameMother
	GivenNameMother
	SurnameFather
	GivenNameFather
	TaxNo
	SocialSecurityNo
	HealthNo
	AccidentalIndications
	Mrz1
	Mrz2
	Mrz3)
fields_offsets=(0 40 120 154 182 214 230 250 310 330 450 570 572 578 598 606 624 744 864 984 1104 1122 1144 1162 1282 1312 1342 1372)

i=0
for field in "${fields_data[@]}"; do
	output="$(dd if=cache/$fn_obj_data iflag=skip_bytes status=none count=1 skip=${fields_offsets[i]} bs=$((${fields_offsets[$((i+1))]}-${fields_offsets[i]})))"
	eval "$field=\"$output\""
	((i++))
done

if $read_address ; then

addrType="$(dd if=cache/$fn_obj_address iflag=skip_bytes status=none count=1 skip=0 bs=2)"

if [ "$addrType" = "N" ]; then
	is_address_foreign=false;
	fields_offsets=(0 2 6 10 110 118 218 230 330 350 450 650 670 770 790 830 870 970 1070 1078 1084 1134 1146)
	fields_address=(
		addrType
		country
		district
		districtDesc
		municipality
		municipalityDesc
		freguesia
		freguesiaDesc
		streettypeAbbr
		streettype
		street
		buildingAbbr
		building
		door
		floor
		side
		place
		locality
		cp4
		cp3
		postal
		numMor)
else
	is_address_foreign=true;
	fields_offsets=(0 2 6 106 406 506 606 706 806 818)
	fields_address=(
		addrType
		country
		countryDescF
		addressF
		cityF
		regioF
		localityF
		postalF
		numMorF)

fi		

i=0
for field in "${fields_address[@]}"; do
	output="$(dd if=cache/$fn_obj_address iflag=skip_bytes status=none count=1 skip=${fields_offsets[i]} bs=$((${fields_offsets[$((i+1))]}-${fields_offsets[i]})))"
	eval "$field=\"$output\""
	((i++))
done

fi

# Save files

f="cache/${DocumentNumberPAN}_${Name} ${Surname}"
mkdir -p "$f"
mv "cache/$fn_obj_data" "$f"
if $read_address ; then
	mv "cache/$fn_obj_address" "$f"
fi
mv "cache/$fn_SOd" "$f"

fn_obj_data="${f}/$fn_obj_data"
fn_obj_address="${f}/$fn_obj_address"
fn_SOd="${f}/$fn_SOd"
fn_SOd_cert="${f}/$fn_SOd_cert"
fn_photo_jp2="${f}/$fn_photo_jp2"
fn_photo_bmp="${f}/$fn_photo_bmp"
fn_photo_jpg="${f}/$fn_photo_jpg"

# Read Photo
# photo starts at offset 1583 and goes until the end of the file
# since the file is 15500 bytes long, the maximum photo size is 13917.
# removing trailing zero bytes reduces my photo to 13023
dd if="$fn_obj_data" status=none skip=1 bs=1583 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r > "$fn_photo_jp2"

# HASHES
#the hash order is not the same as the fields are read, so we list them manually.
hash_id="$({
	echo -n $IssuingEntity
	echo -n $Country
	echo -n $DocumentType
	echo -n $DocumentNumber
	echo -n $DocumentNumberPAN
	echo -n $DocumentVersion
	echo -n $ValidityBeginDate
	echo -n $LocalofRequest
	echo -n $ValidityEndDate
	echo -n $Surname
	echo -n $Name
	echo -n $Gender
	echo -n $Nacionality
	echo -n $DateOfBirth
	echo -n $Height
	echo -n $CivilianIdNumber
	echo -n $SurnameMother
	echo -n $GivenNameMother
	echo -n $SurnameFather
	echo -n $GivenNameFather
	echo -n $AccidentalIndications
	echo -n $TaxNo
	echo -n $SocialSecurityNo
	echo -n $HealthNo
	} | sha256sum -b | head -c 64)"

hash_document_key="$(dd if="$fn_obj_data" iflag=skip_bytes status=none count=1 skip=1372 bs=131 | sha256sum -b | head -c 64)"

# photo including heading starts at offset 1503 and goes until the end of the file
# for the hash we need the heading and to remove trailing zeros
# I didn't find a easy way for this, beside converting it to hexadecimal form first
hash_photo="$(dd if="$fn_obj_data" status=none skip=1 bs=1503 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r | sha256sum -b | head -c 64)"

if $is_address_foreign ; then
hash_address="$({
	echo -n $country		#if hash doesn't work, replace with countryDescF
	echo -n $addressF
	echo -n $cityF
	echo -n $regioF
	echo -n $localityF
	echo -n $postalF
	echo -n $numMorF
	} | sha256sum -b | head -c 64)"
else
hash_address="$({
	echo -n $country
	echo -n $district
	echo -n $districtDesc
	echo -n $municipality
	echo -n $municipalityDesc
	echo -n $freguesia
	echo -n $freguesiaDesc
	echo -n $streettypeAbbr
	echo -n $streettype
	echo -n $street
	echo -n $buildingAbbr
	echo -n $building
	echo -n $door
	echo -n $floor
	echo -n $side
	echo -n $place
	echo -n $locality
	echo -n $cp4
	echo -n $cp3
	echo -n $postal
	echo -n $numMor
	} | sha256sum -b | head -c 64)"
fi

# SOd

# Ignoring the first 4 bytes allows us to parse the SOd file as a CMS/PKCS7 object
# Verify certificate and data signature, extract certificate
echo -n "Document certificate chain: "
tail -c+5 "$fn_SOd" | \
openssl cms -cmsout -inform DER -verify -CApath CA/ -certsout "$fn_SOd_cert" > /dev/null || { echo "SOd INVALID"; exit 1; }

# Verify (online) OCSP
echo -n "Document certificate OCSP : "
if $do_online_OCSP ; then
	OCSP_URI="$(openssl x509 -in "$fn_SOd_cert" -noout -ocsp_uri)"
	ISSUER_HASH="$(openssl x509 -in "$fn_SOd_cert" -noout -issuer_hash)"
	openssl ocsp -issuer "CA/${ISSUER_HASH}.0" -CApath CA/ -url "$OCSP_URI" -cert "$fn_SOd_cert" > /dev/null || { echo "UNABLE TO VERIFY OCSP"; exit 1; }
else
	echo "Verification DISABLED"
fi

echo #new line

hash_id_sod=\
"$(dd if="$fn_SOd" iflag=skip_bytes status=none count=1 skip=95 bs=32 | xxd -p -c 32)"

hash_address_sod=\
"$(dd if="$fn_SOd" iflag=skip_bytes status=none count=1 skip=134 bs=32 | xxd -p -c 32)"

hash_photo_sod=\
"$(dd if="$fn_SOd" iflag=skip_bytes status=none count=1 skip=173 bs=32 | xxd -p -c 32)"

hash_document_key_sod=\
"$(dd if="$fn_SOd" iflag=skip_bytes status=none count=1 skip=212 bs=32 | xxd -p -c 32)"

if $print_sod_values ; then
	echo "Computed hash							 SOd"
	echo "$hash_id $hash_id_sod"
	if $read_address ; then
		echo "$hash_address $hash_address_sod"
	fi
	echo "$hash_photo $hash_photo_sod"
	echo "$hash_document_key $hash_document_key_sod"
fi

[ "$hash_id" = "$hash_id_sod" ]				|| { echo "ID data TAMPERED!"; error=true; }
if $read_address ; then
	[ "$hash_address" = "$hash_address_sod" ]	|| { echo "Address TAMPERED!"; error=true; }
fi
[ "$hash_photo" = "$hash_photo_sod" ]			|| { echo "Photo TAMPERED!"; error=true; }
[ "$hash_document_key" = "$hash_document_key_sod" ]	|| { echo "Doc key TAMPERED!"; error=true; }

if $error ; then
	exit 1
fi

# PRINT STUFF

if $print_all_fields ; then
	for field in "${fields_data[@]}"; do
		printf '%-22s: %s\n' "$field" "${!field}"
	done
else
	echo "$Name $Surname     $DateOfBirth"
	echo "$DocumentNumber     $ValidityEndDate     $LocalofRequest"
	# IF Accidental Indications exist, they are usually very significative so always print them!
	[ -n "$AccidentalIndications" ] && echo $AccidentalIndications
fi

if $read_address ; then
	for field in "${fields_address[@]}"; do
		printf '%-22s: %s\n' "$field" "${!field}"
	done
fi

check_package "opj_decompress" "libopenjp2-tools"
opj_decompress -i "$fn_photo_jp2" -o "$fn_photo_bmp" > /dev/null 2>&1
convert "$fn_photo_bmp" "$fn_photo_jpg"
if $print_photo_ascii ; then
	check_package "jp2a" "jp2a"
	jp2a "$fn_photo_jpg" --height=50
fi
