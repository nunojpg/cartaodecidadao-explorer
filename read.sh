#!/bin/bash
# Copyright (C) 2016, Nuno Goncalves <nunojpg@gmail.com>

# trace and notepad objects are not validated by SOD
# we verify the SOD certificate with CRL but not OCSP because OpenSSL command line tool doesn't allow it easily

# TODO:
# read and verify address
# authenticate document

read_address="false"
download_crl="true"

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

func1() {
	dd if="cache/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=${fields_offsets[i]} bs=$((${fields_offsets[$((i+1))]}-${fields_offsets[i]}))
}

pins_list="$(pkcs15-tool --wait --verbose --list-pins 2> >(tee $filename_opensc_cardsearch >&2))"

cardsearch="$(<$filename_opensc_cardsearch)"
rm $filename_opensc_cardsearch
if [[ "$cardsearch" != *Found\ CARTAO\ DE\ CIDADAO! ]]; then exit; fi

driver="${pins_list#*driver }"
echo "${driver%%.*}"

auth="$(pin_tries_left "$pins_list" "Auth PIN")"
sign="$(pin_tries_left "$pins_list" "Sign PIN")"
address="$(pin_tries_left "$pins_list" "Address PIN")"

echo "PIN tries left [AUTH: $auth] [SIGN: $sign] [Address: $address]"

[ -a "$filename_citizen_data" ] && rm "$filename_citizen_data"
[ -a "$filename_sod" ] && rm "$filename_sod"
[ -a "$filename_trace" ] && rm "$filename_trace"
[ -a "$filename_sod_pkcs7_der" ] && rm "$filename_sod_pkcs7_der"
[ -a "$filename_sod_certificate_pem" ] && rm "$filename_sod_certificate_pem"
[ -a "$filename_hashes_der" ] && rm "$filename_hashes_der"
[ -a "$filename_photo_jp2" ] && rm "$filename_photo_jp2"
[ -a "$filename_photo_bmp" ] && rm "$filename_photo_bmp"

mkdir -p cache
pkcs15-tool --read-data-object 'Citizen Data' --output "cache/$filename_citizen_data" > /dev/null 2>&1
pkcs15-tool --read-data-object 'SOD' --output "cache/$filename_sod" > /dev/null 2>&1
#pkcs15-tool --read-data-object 'TRACE' --output "cache/$filename_trace" > /dev/null

# ID DATA

fields_offsets=(0 40 120 154 182 214 230 250 310 330 450 570 572 578 598 606 624 744 864 984 1104 1122 1144 1162 1282 1312 1342 1372);
#fields_count=$((${#fields_offsets[@]}-1));
#for ((i=0;i<fields_count;i++)); do
#	a1=${fields_offsets[$i]};
#	a2=${fields_offsets[$((i+1))]};
#	dd if="$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=${a1} bs=$((a2-a1)) && echo
#done

i=0;
IssuingEntity="$(func1)"; ((i++))
Country="$(func1)"; ((i++))
DocumentType="$(func1)"; ((i++))
DocumentNumber="$(func1)"; ((i++))
DocumentNumberPAN="$(func1)"; ((i++))
DocumentVersion="$(func1)"; ((i++))
ValidityBeginDate="$(func1)"; ((i++))
LocalofRequest="$(func1)"; ((i++))
ValidityEndDate="$(func1)"; ((i++))
Surname="$(func1)"; ((i++))
Name="$(func1)"; ((i++))
Gender="$(func1)"; ((i++))
Nacionality="$(func1)"; ((i++))
DateOfBirth="$(func1)"; ((i++))
Height="$(func1)"; ((i++))
CivilianIdNumber="$(func1)"; ((i++))
SurnameMother="$(func1)"; ((i++))
GivenNameMother="$(func1)"; ((i++))
SurnameFather="$(func1)"; ((i++))
GivenNameFather="$(func1)"; ((i++))
TaxNo="$(func1)"; ((i++))
SocialSecurityNo="$(func1)"; ((i++))
HealthNo="$(func1)"; ((i++))
AccidentalIndications="$(func1)"; ((i++))
Mrz1="$(func1)"; ((i++))
Mrz2="$(func1)"; ((i++))
Mrz3="$(func1)"; ((i++))

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


folder="cache/${DocumentNumberPAN}_$Name $Surname"
mkdir -p "$folder"
mv "cache/$filename_citizen_data" "$folder"
mv "cache/$filename_sod" "$folder"
#mv "cache/$filename_trace" "$folder"

# DOCUMENT KEY

#dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1372 bs=128 | hexdump
#dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1500 bs=3 | hexdump
hash_document_key="$(dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1372 bs=131 | sha256sum -b | head -c 64)"


# PHOTO

#dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1503 bs=34	# Photo CBEFF
#dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1537 bs=14	# Photo FACIALRECHDR
#dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1551 bs=20	# Photo FACIALINFO
#dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1571 bs=12	# Photo IMAGEINFO
dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1583 bs=14128 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r > "${folder}/$filename_photo_jp2"
#we need to trim the photo trailing zeros. I didn't find a easy way for this, beside converting it to hexadecimal form first
hash_photo="$(dd if="${folder}/$filename_citizen_data" iflag=skip_bytes status=none count=1 skip=1503 bs=14208 | xxd -p | tr -d '\n' | sed 's/\(00\)*$//' | xxd -p -r | sha256sum -b | head -c 64)"


# ADDRESS

## NOT IMPLEMENTED


# SOD

# Ignoring the first 4 bytes allows us to parse the SOD file as a PKCS7 object
tail -c+5 "${folder}/$filename_sod" > "${folder}/$filename_sod_pkcs7_der"

# Verify Data and Certificate signatures
openssl smime -inform DER -in "${folder}/$filename_sod_pkcs7_der" -verify -CApath CA/ > "${folder}/$filename_hashes_der" 2> /dev/null \
		|| { echo "SOD INVALID"; exit; }

# Extract certificate and convert to PEM
openssl pkcs7 -inform DER -in "${folder}/$filename_sod_pkcs7_der" -print_certs > "${folder}/$filename_sod_certificate_pem"

# Verify Certificate signature (again) and CRL (requires internet connection)
[ "$download_crl" = "true" ] && openssl verify -verbose -crl_download -crl_check -CApath CA/ "${folder}/$filename_sod_certificate_pem" > /dev/null \
		|| { echo "UNABLE TO VERIFY CRL"; exit; }		

hash_id_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=31 bs=32 | xxd -p -c 32)"
hash_address_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=70 bs=32 | xxd -p -c 32)"
hash_photo_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=109 bs=32 | xxd -p -c 32)"
hash_document_key_sod="$(dd if="${folder}/$filename_hashes_der" iflag=skip_bytes status=none count=1 skip=148 bs=32 | xxd -p -c 32)"

[ "$hash_id" = "$hash_id_sod" ]				|| echo "ID data TAMPERED!"
if [ "$read_address" = "true" ]; then
	[ "$hash_address" = "$hash_address_sod" ]	|| echo "Address TAMPERED!"
fi
[ "$hash_photo" = "$hash_photo_sod" ]			|| echo "Photo TAMPERED!"
[ "$hash_document_key" = "$hash_document_key_sod" ]	|| echo "Doc key TAMPERED!"



# PRINT STUFF

echo "$Name $Surname     $DateOfBirth"
echo "$DocumentNumber     $ValidityEndDate     $LocalofRequest"
[ -n "$AccidentalIndications" ] && echo $AccidentalIndications	# IF Accidental Indications exist, they are usually very significative so always print them!

j2k_to_image -i "${folder}/$filename_photo_jp2" -o "${folder}/$filename_photo_bmp" > /dev/null 2>&1
convert "${folder}/$filename_photo_bmp" "${folder}/$filename_photo_jpg"
jp2a "${folder}/$filename_photo_jpg" --height=50
#eog "${folder}/$filename_photo_bmp"
