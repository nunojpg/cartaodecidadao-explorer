#!/bin/bash
# Copyright (C) 2016, Nuno Goncalves <nunojpg@gmail.com>

# trace and notepad objects are not validated by SOD
# we verify the SOD certificate with CRL but not OCSP because OpenSSL command line tool doesn't allow it easily
# document can not be validated (INTERNAL_AUTH/ICAO MRTD AA) because it requires mutual authentication with a government issued CVC

# TODO:
# read address

error=false

print_all_fields=false
print_photo_ascii=false
read_address=false
download_crl=true

filename_opensc_cardsearch="opensc_cardsearch"
filename_citizen_data="object_citizen_data"
#filename_citizen_address="object_citizen_address"
filename_sod="object_SOD"
#filename_trace="object_trace"
filename_sod_pkcs7_der="document_sign_pkcs7.der"
filename_sod_certificate_pem="document_sign_certificate.pem"
filename_hashes_der="sod_hashes.der"
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
Usage: ${0##*/} [-hacp]
CARTAO DE CIDADAO EXPLORER
Read, cryptographically authenticate data, and print it.

    -h          display this help and exit
    -a		Print all identification fields
    -c          Disable CRL download
    -p		Print photo ascii art
EOF
}

while getopts "hpac" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
	a)  print_all_fields=true
            ;;
	c)  download_crl=false
	    ;;
        p)  print_photo_ascii=true
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
remove_file "$filename_sod"
remove_file "$filename_trace"
remove_file "$filename_sod_pkcs7_der"
remove_file "$filename_sod_certificate_pem"
remove_file "$filename_hashes_der"
remove_file "$filename_photo_jp2"
remove_file "$filename_photo_bmp"

mkdir -p cache
pkcs15-tool --read-data-object 'Citizen Data' --output "cache/$filename_citizen_data" > /dev/null 2>&1
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


# Save files

folder="cache/${DocumentNumberPAN}_$Name $Surname"
mkdir -p "$folder"
mv "cache/$filename_citizen_data" "$folder"
mv "cache/$filename_sod" "$folder"
#mv "cache/$filename_trace" "$folder"

# Read Photo

dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1583 bs=14128 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r > "${folder}/$filename_photo_jp2"

# Read Address


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

hash_document_key="$(dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1372 bs=131 | sha256sum -b | head -c 64)"
#we need to trim the photo trailing zeros. I didn't find a easy way for this, beside converting it to hexadecimal form first
hash_photo="$(dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1503 bs=14208 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r | sha256sum -b | head -c 64)"


## NOT IMPLEMENTED


# SOD

# Ignoring the first 4 bytes allows us to parse the SOD file as a PKCS7 object
tail -c+5 "${folder}/$filename_sod" > "${folder}/$filename_sod_pkcs7_der"

# Verify Data and Certificate signatures
openssl smime -inform DER -in "${folder}/$filename_sod_pkcs7_der" -verify -CApath CA/ > "${folder}/$filename_hashes_der" 2> /dev/null \
		|| { echo "SOD INVALID"; exit 1; }

# Extract certificate and convert to PEM
openssl pkcs7 -inform DER -in "${folder}/$filename_sod_pkcs7_der" -print_certs > "${folder}/$filename_sod_certificate_pem"

# Verify Certificate signature (again) and CRL (requires internet connection)
[ "$download_crl" = "true" ] && openssl verify -verbose -crl_download -crl_check -CApath CA/ "${folder}/$filename_sod_certificate_pem" > /dev/null \
		|| { echo "UNABLE TO VERIFY CRL"; exit 1; }		

hash_id_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=31 bs=32 | xxd -p -c 32)"
hash_address_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=70 bs=32 | xxd -p -c 32)"
hash_photo_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=109 bs=32 | xxd -p -c 32)"
hash_document_key_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=148 bs=32 | xxd -p -c 32)"

[ "$hash_id" = "$hash_id_sod" ]				|| { echo "ID data TAMPERED!"; error=true; }
if "$read_address" ; then
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

check_package "j2k_to_image" "openjpeg-tools"
j2k_to_image -i "${folder}/$filename_photo_jp2" -o "${folder}/$filename_photo_bmp" > /dev/null 2>&1
convert "${folder}/$filename_photo_bmp" "${folder}/$filename_photo_jpg"
if "$print_photo_ascii" ; then
	check_package "jp2a" "jp2a"
	jp2a "${folder}/$filename_photo_jpg" --height=50
fi
#eog "${folder}/$filename_photo_bmp"
