#!/bin/bash
# Copyright (C) 2016-2017, Nuno Goncalves <nunojpg@gmail.com>

# trace and notepad objects are not validated by SOD
# we verify the SOD certificate with CRL but not OCSP because OpenSSL command line tool doesn't allow it easily
# document can not be validated (INTERNAL_AUTH/ICAO MRTD AA) because it requires mutual authentication with a government issued CVC

# TODO:
# read address

error=false

print_all_fields=false
print_photo_ascii=false
read_address=false
print_sod_values=false
download_crl=true

filename_opensc_cardsearch="opensc_cardsearch"
filename_citizen_data="object_citizen_data"
filename_citizen_address="object_citizen_address"
filename_sod="object_SOD"
filename_sod_certificate="document_sign_certificate"
filename_photo_jp2="photo.jp2"
filename_photo_bmp="photo.bmp"
filename_photo_jpg="photo.jpg"

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
    -c          Disable CRL download
    -p		Print photo ascii art
    -s		Print SOD values
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
	c)  download_crl=false
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

pins_list="$(pkcs15-tool --wait --verbose --list-pins 2> >(tee $filename_opensc_cardsearch >&2))"

cardsearch="$(<$filename_opensc_cardsearch)"
rm $filename_opensc_cardsearch
if [[ "$cardsearch" != *Found\ CARTAO\ DE\ CIDADAO! ]]; then exit; fi

driver="${pins_list#*driver }"
echo "${driver%%.*}"

auth="$(pin_tries_left "$pins_list" "Auth PIN")"
sign="$(pin_tries_left "$pins_list" "Sign PIN")"
address="$(pin_tries_left "$pins_list" "Address PIN")"

printf 'PIN tries left        : [AUTH: %s] [SIGN: %s] [Address: %s]\n' "$auth" "$sign" "$address"

remove_file "$filename_citizen_data"
remove_file "$filename_citizen_address"
remove_file "$filename_sod"
remove_file "$filename_sod_certificate"
remove_file "$filename_photo_jp2"
remove_file "$filename_photo_bmp"

mkdir -p cache
pkcs15-tool --read-data-object 'Citizen Data' --output "cache/$filename_citizen_data" > /dev/null 2>&1
if $read_address ; then
	pkcs15-tool --read-data-object 'Citizen Address Data' --output "cache/$filename_citizen_address"
fi
pkcs15-tool --read-data-object 'SOD' --output "cache/$filename_sod" > /dev/null 2>&1
#pkcs15-tool --read-data-object 'TRACE' --output "cache/$filename_trace" > /dev/null

# read ID data
fields=(IssuingEntity
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
for field in "${fields[@]}"
do
	output="$(dd if=cache/$filename_citizen_data iflag=skip_bytes status=none count=1 skip=${fields_offsets[i]} bs=$((${fields_offsets[$((i+1))]}-${fields_offsets[i]})))"
	eval "$field=\"$output\""
	((i++))
	if $print_all_fields ; then
		printf '%-22s: %s\n' "$field" "${!field}"
	fi
done

if $read_address ; then

addrType="$(dd if=cache/$filename_citizen_address iflag=skip_bytes status=none count=1 skip=0 bs=2)"

if [ "$addrType" = "N" ]; then
	is_address_foreign=false;
	fields_offsets=(0 2 6 10 110 118 218 230 330 350 450 650 670 770 790 830 870 970 1070 1078 1084 1134 1146)
	fields=(addrType
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
	fields=(addrType
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
for field in "${fields[@]}"
do
	output="$(dd if=cache/$filename_citizen_address iflag=skip_bytes status=none count=1 skip=${fields_offsets[i]} bs=$((${fields_offsets[$((i+1))]}-${fields_offsets[i]})))"
	eval "$field=\"$output\""
	((i++))
	if $read_address ; then
		printf '%-22s: %s\n' "$field" "${!field}"
	fi
done

fi

# Save files

f="cache/${DocumentNumberPAN}_$Name $Surname"
mkdir -p "$f"
mv "cache/$filename_citizen_data" "$f"
if $read_address ; then
	mv "cache/$filename_citizen_address" "$f"
fi
mv "cache/$filename_sod" "$f"
#mv "cache/$filename_trace" "$f"

# Read Photo
# photo starts at offset 1583 and goes until the end of the file
# since the file is 15500 bytes long, the maximum photo size is 13917.
# removing trailing zero bytes reduces my photo to 13023
dd if="${f}/$filename_citizen_data" status=none skip=1 bs=1583 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r > "${f}/$filename_photo_jp2"

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

hash_document_key="$(dd if="${f}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1372 bs=131 | sha256sum -b | head -c 64)"

# photo including heading starts at offset 1503 and goes until the end of the file
# for the hash we need the heading and to remove trailing zeros
# I didn't find a easy way for this, beside converting it to hexadecimal form first
hash_photo="$(dd if="${f}/$filename_citizen_data" status=none skip=1 bs=1503 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r | sha256sum -b | head -c 64)"

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

# SOD

# Ignoring the first 4 bytes allows us to parse the SOD file as a CMS/PKCS7 object
# Verify certificate and data signature, extract certificate
tail -c+5 "${f}/$filename_sod" | \
openssl cms -cmsout -inform DER -verify -CApath CA/ -certsout "${f}/$filename_sod_certificate" > /dev/null || { echo "SOD INVALID"; exit 1; }

# Verify Certificate signature (again) and CRL (requires internet connection)
[ "$download_crl" = "true" ] && \
openssl verify -verbose -crl_download -crl_check -CApath CA/ "${f}/$filename_sod_certificate" > /dev/null || { echo "UNABLE TO VERIFY CRL"; exit 1; }		

hash_id_sod=\
"$(dd if="${f}/$filename_sod" iflag=skip_bytes status=none count=1 skip=95 bs=32 | xxd -p -c 32)"

hash_address_sod=\
"$(dd if="${f}/$filename_sod" iflag=skip_bytes status=none count=1 skip=134 bs=32 | xxd -p -c 32)"

hash_photo_sod=\
"$(dd if="${f}/$filename_sod" iflag=skip_bytes status=none count=1 skip=173 bs=32 | xxd -p -c 32)"

hash_document_key_sod=\
"$(dd if="${f}/$filename_sod" iflag=skip_bytes status=none count=1 skip=212 bs=32 | xxd -p -c 32)"

if $print_sod_values ; then
	echo "Computed hash							 SOD"
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

if ! $print_all_fields ; then
	echo "$Name $Surname     $DateOfBirth"
	echo "$DocumentNumber     $ValidityEndDate     $LocalofRequest"
	[ -n "$AccidentalIndications" ] && echo $AccidentalIndications	# IF Accidental Indications exist, they are usually very significative so always print them!
fi

check_package "opj_decompress" "libopenjp2-tools"
opj_decompress -i "${f}/$filename_photo_jp2" -o "${f}/$filename_photo_bmp" > /dev/null 2>&1
convert "${f}/$filename_photo_bmp" "${f}/$filename_photo_jpg"
if $print_photo_ascii ; then
	check_package "jp2a" "jp2a"
	jp2a "${f}/$filename_photo_jpg" --height=50
fi
#eog "${folder}/$filename_photo_bmp"
