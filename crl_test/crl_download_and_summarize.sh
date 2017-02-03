#!/bin/bash
# Copyright (C) 2017, Nuno Goncalves <nunojpg@gmail.com>

PKI="https://pki.cartaodecidadao.pt/publico/lrc/"

wget $PKI --no-verbose
grep -Po '(?<=href=")[^"]*html' index.html | while read -r line ; do
    wget "${PKI}${line}" --no-verbose
done

grep -hPo '(?<=href=")[^"]*crl' *.html | while read -r line ; do
    wget "${PKI}${line}" --no-verbose
done

rm *.html

header=" Total Reason Removd   Hold Cessat Withdr"
echo "$header"
for file in *.crl; do
	openssl crl -in $file -inform DER -text -noout > tmp

	declare $(awk '
	BEGIN { split("Total WithReason RemoveFromCRL CertificateHold CessationOfOperation PrivilegeWithdrawn", keyword)
		for (i in keyword) count[keyword[i]]=0
	}
	/Serial/  { count["Total"]++ }
	/Reason/  { count["WithReason"]++ }
	/Remove From CRL/  { count["RemoveFromCRL"]++ }
	/Certificate Hold/  { count["CertificateHold"]++ }
	/Cessation Of Operation/  { count["CessationOfOperation"]++ }
	/Privilege Withdrawn/  { count["PrivilegeWithdrawn"]++ }
	END   {
		for (i in keyword) print sprintf("%s=%d", keyword[i], count[keyword[i]])
	}' < tmp)

	OtherReasons=$((WithReason-RemoveFromCRL-CertificateHold-CessationOfOperation-PrivilegeWithdrawn))

	((Total > 0)) && printf -v Total_s "%6d" $Total || unset Total_s
	((WithReason > 0)) && printf -v WithReason_s "%6d" $WithReason || unset WithReason_s
	((RemoveFromCRL > 0)) && printf -v RemoveFromCRL_s "%6d" $RemoveFromCRL || unset RemoveFromCRL_s
	((CertificateHold > 0)) && printf -v CertificateHold_s "%6d" $CertificateHold || unset CertificateHold_s
	((CessationOfOperation > 0)) && printf -v CessationOfOperation_s "%6d" $CessationOfOperation || unset CessationOfOperation_s
	((PrivilegeWithdrawn > 0)) && printf -v PrivilegeWithdrawn_s "%6d" $PrivilegeWithdrawn || unset PrivilegeWithdrawn_s

	printf "%6s %6s %6s %6s %6s %6s %s\n" \
		"$Total_s" \
		"$WithReason_s" \
		"$RemoveFromCRL_s" \
		"$CertificateHold_s" \
		"$CessationOfOperation_s" \
		"$PrivilegeWithdrawn_s" \
		"$file"
	if ((OtherReasons > 0)); then
		echo "CRL had unexpected reasons:"
		sed -n '/Reason/{n;p}' tmp | sort | uniq -c
	fi


	rm tmp
	rm $file
done
echo "$header"
echo "Total : total serials in list"
echo "Reason: with reason; (following)"
echo "Removd: 	Remove From CRL"
echo "Hold  : 	Certificate Hold"
echo "Cessat: 	Cessation Of Operation"
echo "Withdr: 	Privilege Withdrawn"
