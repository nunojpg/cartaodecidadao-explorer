# cartaodecidadao-explorer
This is meant to demo reading a Cartão de Cidadão / PTEID (Portuguese eID card) with a shell script.

This script depends exclusively on Free/Open Source Middleware [OpenSC](https://github.com/OpenSC/OpenSC). The Portuguese Government also makes available a [Open Souce Middleware](https://svn.gov.pt/projects/ccidadao) which is not used here.

There is no particular use case. You can validate the reading works and edit the script to your need. You can also parse the result of this script, but that is not recommended or safe. No assurance is made for the stability of the output.

Features or bug fixes pull requests are highly appreciated!

## Dependencies

This tool depends on [OpenSC](https://github.com/OpenSC/OpenSC) with minimum version 0.17. (Ubuntu 18.04 / Debian 10 buster)

If you have a recent card (2019), you likely need version 0.20. (expected Ubuntu 20.04 / Debian 10 buster)

If you don't have the required version, just download and compile [OpenSC](https://github.com/OpenSC/OpenSC) from source to use it.

Ubuntu 18.04 example:

```bash
sudo apt remove opensc #Make sure OpenSC distributions package is not installed
sudo apt install autoconf libssl-dev pcscd libpcsclite-dev pkg-config
wget https://github.com/OpenSC/OpenSC/releases/download/0.20.0/opensc-0.20.0.tar.gz
tar -xf opensc-0.20.0.tar.gz
cd opensc-0.20.0
./configure --prefix=/usr --sysconfdir=/etc/opensc
make
sudo make install
```

Beside OpenSC the following other dependencies are required in a Debian/Ubuntu system:

```bash
sudo apt install libopenjp2-tools jp2a
```

## What it does and how to use it

The script will wait for a PTEID to be inserted, read the card, validate it and print some data.

The validation is done by reading the SOd (Security Object document), which contains a DSR (Document Signing Certificate) and hashes for the personal data on the card.

The DSR is validated with the full-chain certificates available under [CA](./CA/). The Certification entity certificates for the DSR can be found [here](https://pki.cartaodecidadao.pt/publico/certificado/cc_ec_cidadao/). If you need to add any of them you can convert and hash them with [this](./CA/convert_and_hash.sh) script.

Then the signed and validated hashes are compared against the personal data (and address if we are also reading it).

This process requires Internet connectivity for OCSP. This can be disabled with a command-line option.

This is a sample run (with some personal data replaced with generic):
```
$./read-pteid.sh -h
Usage: read-pteid.sh [-habcp]
CARTAO DE CIDADAO EXPLORER
Read, cryptographically authenticate data, and print it.

    -h          display this help and exit
    -a		Print all identification fields
    -b		Print address
    -c          Disable OCSP
    -p		Print photo ascii art
    -s		Print SOD values

$./read-pteid.sh -p
Waiting for a card to be inserted...
Trying to find a PKCS#15 compatible card...
Found CARTAO DE CIDADAO!
Gemalto GemSafe V1 applet
PIN tries left        : [AUTH: 3] [SIGN: 3] [Address: 3]
JOSÉ SÓCRATES CARVALHO PINTO DE SOUSA     06 09 1967
99999999 9 ABC     01 01 2015     CRCiv. Evora
KXXXXKKKXXXXXKKKXXXXKKKXXXXKKKKXXKKKKKKXKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXKXXXXXKKKK
KXXNXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXKKX
KXXNNXXXXXXXXXXXXNXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXKK
KXXNNXXXXXXNXXXXXXNXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXKKXXXXKKX
KXXXNNXXXXNNNXXXXNNNXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXKX
KXXXXXXXXXXXXXXXXXNNXXXXXXXXXXKKK0OOOOO0KXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
KXXXXXXXXXXXXXXXXXNNXXXXXXKkdlc:::::::::clodk0XXXXXXXXXXXXXXXXXXXXXXXXNNXXX
KXXXNNXXXXXNNXXXXXXNXXKkdl::::::::::ccccccccccokKXNNXNNNNNNNNNNWNNNNNNWWNNN
XXXXXNNXXXXXXXXXXXXX0dc:ccccc:ccccccllllllllccccld0NNNWWWWWNNNWWWWNNNNWWNNN
XXXXNNNNXXNNNNNNNNKxccclllllcccllllloooooooooooooold0NNWWWWNNNWWWWNNNNWWWNN
XNNNNNWNNNNWWWWNNKlccloolloolllloooodooodddddddddddoldXWWWWNNNWWWWNNNNWWWNN
NWWWWWWWWWWWWWWWXocllooooooooooooddxddddxxdxxxxxxxdddloKWWWWNNWWWWWNNNWWWWW
NWWWWWWWWWWWWWWNxlllooooooooooooodddddxxxkxxkkkkkxxddoodKWWWWWWWWWWNNNWWWWW
NWWWWWWWWWWWWWWKlllloooooooooooooooddddxxxxkkkkOkxxxddoodNWWWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWWkllllloooooooollloooddddddxkkkkkkkkkxddoooXWWWNWWWWWWNWWWWWW
NWWWWWWWWWWWWWWkllllloooooooooooooddddddddxxxkkkkkxddddodXWWWNWWWWWWNNWWWWW
NWWWWWWWWWWWWWWOllllloolloooddddddddddooddxxxkkkkkkxdxdodNWWWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWWOlllllllloooooodddddxxddodddxkkkkkkkxxxdokNWWWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWWKllllllll:;:::ccclooddoolllooolloolldddddOWWWWWWWWWWWWWWWWWW
NWWWWWWWWWWWNKKKololc:,,,,''''''',;ccll:;,,'''''',;;:ldd0NXNWWWWWWWWWWWWWWW
NWWWWWWWWWWNxcllolllc:;;,,''''''',;:loxdl:;,,'',;:clooddxxoo0WWWWWWWWWWWWWW
NWWWWWWWWWWNd:ollloll:;,',,...'..';ldxkkd:''''.':;;:ldxxxkkcxWWWWWWWWWWWWWW
NWWWWWWWWWWNxllc:coolcc::;;,''''';codxxkxl;,,,;:cloodxxdodklkWWWWWWWWWWWWWW
NWWWWWWWWWWWOl:;cloollllc:;;,,;;cllooddxxxxolcclodxkkxxxl:odKWWWWWWWWWWWWWW
NWWWWWWWWWWWXlcccllllooollccccllllloddxkxxddxdddxxkkkkxdccoxNWWWWWWWWWWWWWW
NWWWWWWWWWWWNOloollllloollllclllllloddxxxxddxxxxxxkkkxxddooKWWWWWWWWWWWWWWW
NWWWWWWWWWWWWNkdoollllllllllllcclllooldkxxxdoodxxxxxxxddddkNWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWNkddolllllllllccccc:,;::coccoddoodxkxdxxddxkKWWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWWWWW0llllloollccllc:,,,;:lllodddoodxkxxxdxNWWWWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWWWWWNoclllollc:ccc:;;;::;ccllooolodxxkxxdkNWWWWWWWWWWWWWWWWNW
NWWWWWWWWWWWWWWWWWWOcclllll:;,,;;;;;;:::ccllc:;coxxxxdd0WWWWWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWWWWWWNdcccccc;,,;;;;;;;;;:ccclodlcoxxxddkNWWWWWWWWWWWWWWWWWWW
NWWWWWWWWWWWWWWWWWWWXoccccc;;:cc::;;;;;:clodddolodddodXWWWWWWWWWWWWWWWWWWNW
NWWWWWWWWWWWWWWWWWWWWOc::::;;;::::;;;;;:cloooooloooooxNWWWWWWWWWWWWWWWWWWNW
NWWWWWWWWWWWWWWWWWWWWKol:::;;:::::::::cclollolllllloxxXWWWWWWWWWWWWWWWWWWNW
NWWWWWWWWWWWWWWWWWWWWNdll:::;;;::::::::clllllllllloxxxKWWWWWWWWWWWWWWWWWWNW
NWWWWWWWWWWWWWWWWWWWWWxllc::;;;;;;;,;;;;:cccccccloxxkxxkKWWWWWWWWWWNWWWWWNN
NWWWWWWWWWWWWWWWWWWWWWOlllcc:;;;,,,,,,,,;;::cclodxxkkxxoxMNNNWWWWWWWWWWWWNN
NWWWWWWWWWWWWWWWWWWX0kdllllcc::;;;,,,,,;;::cloodxxxxkkxdKMX0ddkXNWWNNNWWWNN
NWWWWWWWWWWWWWWWWNo:clllllllcc::;;;;;;;::clloodxxxkkkkkOWMMMNNOkxdxxxOKNNNN
NWWWWWWWWWWWWWWNNXoclolllllllccc::;;;;:cclloodxxxxkkkkkNMMMMMWKKWWX00XK0OOO
NWWWWWWWWWWNNXOxx0Kllolllllllcccc:::;;:clooododdxxxxxdXMMMWWMWK0KNMWXNMWXNW
NWWWWWWWNOdlc:lxXWNKlllolllllccccc::;;:cloodoodddddldNMMMMWWNNXXKXWMWWMMWKX
NWWNX0kddk000KNNNWWNKocllllllccc::::::cclooolooolc:xWMMMMMWXXK0KKKXNWMMMWXK
KOxdxk0XWWNXKKNWWNWWWXxccllllllcccccccccllllllc::oXMMMMWWWNXXX00K0KXNWMMMNX
kKNNWWWWWWWXXNNNNNWWWWNKxlclllllllllcccccccccccd0WMMMWNXNWNXXNXKXKKXNMMMMNX
NWWNNWWWWWWWWWNNXXNNWWWWNXOkdoooloollccccllldOXMMMMWWWNNNWNNNNNWWNKXNWMMMWN
NWWNXNNWWMMWNWWWNXNNNNNNWNXXXK0kxolllllldxOXWMMMMWNNWWWWWWWWWWMMWXKXXWMMMMW
NWWNXXNWMMMWWWWWWNNWNNNNXXNNNXK0000OOO0KXXNWWMMWNKXWMWWWWWWWMMMMWXXXNWMMMMM
```

## TODO

* Notepad writing is not implemented. I don't know if it uses a standard PKCS15 procedure.

## LIMITATIONS

* It is not possible to do Card/Chip authentication like in the MRTD Biometric Passport AA (active authentication). This is supported by the PTEID, and is used by the official Middleware during Mutual Authentication (using a CVC), for example for the Address Change process, and it is not possible by the general public.
* Fingerprint Match-on-card applet is not supported in any way. Patches or documentation are greatly appreciated!
