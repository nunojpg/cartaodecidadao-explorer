# cartaodecidadao-explorer
This is meant to demo reading a Cartão de Cidadão / PTEID (Portuguese eID card) with a shell script.

This script depends exclusively on Free/Open Source Middleware [OpenSC](https://github.com/OpenSC/OpenSC). The Portuguese Government also makes available a [Open Souce Middleware](https://svn.gov.pt/projects/ccidadao) which is not used here.

There is no particular use case. You can validate the reading works and edit the script to your need.

Features or bug fixes pull requests are highly appreciated!

## Dependencies

The features implemented require [OpenSC](https://github.com/OpenSC/OpenSC) with patchs commited on 2016-06-13, and is expected to only reach mainline with OpenSC 0.17.

Please download and compile [OpenSC](https://github.com/OpenSC/OpenSC) from source to use it.

Ubuntu 16.04 example:

```bash
sudo apt remove opensc #Make sure OpenSC distributions package are not installed
sudo apt install autoconf libssl-dev pcscd libpcsclite-dev pkg-config
git clone https://github.com/OpenSC/OpenSC.git
cd OpenSC
./configure --prefix=/usr
make
sudo make install
```

Beside OpenSC the following other dependencies are required in a Debian/Ubuntu system:

```bash
sudo apt install 
```

## What it does and how to use it

The script will wait for a PTEID to be inserted, read the card, validate it and print some data.

The validation is done by reading the SOD (Document Security Object), which contains a DSR (Document Signing Certificate) and hashes for the personal data on the card.

The DSR is validated with the full-chain certificates available under [CA](./CA/). The Certification entity certificates for the DSR can be found [here](https://pki.cartaodecidadao.pt/publico/certificado/cc_ec_cidadao/). If you need to add any of them you can convert and hash them with [this](./CA/convert_and_hash.sh) script.

Then the signed and validated hashes are compared against the personal data (except address since we are not reading it).

This process requires Internet connectivity to verify the CRL for the full-chain certificates. This can be disabled on the script header.

This is a sample output:


## TODO

* Currently I am unable to do Card/Chip authentication like in the MRTD Biometric Passport AA (active authentication). This is supported by the PTEID, and is used by the official Middleware during Mutual Authentication (using a CVC), for example for the Address Change process. How it is done and if it is possible without a CVC is unknown.
* Fingerprint Match-on-card applet is not supported in any way. 
* Notepad writing is not implemented. I don't know if it uses a standard PKCS15 procedure.
* Address parsing is not implemented. It is very easy to do. I just don't need it at this time.



