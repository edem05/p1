#!/bin/bash
#
# Author: Eli
#
# Date: 11/28/2018
#
# Description: This script enables any user to install the Secure Socket API without any errors.
clear
echo "[*] Checking if user is root."
root_check=$(whoami)
if [[ $root_check != "root" ]]; then
	echo "[!] In order to proceed with installations and running SSA itself, you need to be a root user."
	echo "[*] Please enter 'sudo su', then enter your root password and try running this script again."
else

echo "[*] removing ssa and ssa-daemon"
rm -rf ssa* # This removes both ssa and ssa-daemon, if they exist
echo ""

# This is the install_packages.sh script in ssa-daemon directory with other packages addded to it.
echo "(1/4) Checking if you are running Fedora or Ubuntu."
DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
test -n $DISTRO && echo "[+] Distribution Detected: ${DISTRO}" || echo "[-] Could not determine OS type."

if [[ "${DISTRO}" == 'Fedora' ]]; then
	echo "[*] Checking for updates"
	dnf -y update
	dnf -y upgrade
        echo '[+] Installing Fadora libraries for tls_wrapper'
        sudo dnf -y install \
                                                  avahi-devel \
                                                  elfutils-libelf-devel \
                                                  glib-devel \
                                                  gtk3-devel \
                                                  kernel-devel \
                                                  libconfig-devel \
                                                  libevent-devel \
                                                  libnl3-devel \
                                                  libnotify-devel \
                                                  openssl-devel \
                                                  qrencode \
                                                  libnet-devel \
                                                  nano \
                                                  make \
                           			  git \
						  kernel-devel \
						  kernel-headers \

        echo '[+] Packages Installed'
fi

if [[ "${DISTRO}" == '"Ubuntu"' ]]; then
	echo "[*] Checking for updates"
	apt-get -y update
	apt-get -y upgrade
        echo 'Installing Ubuntu libraries for tls_wrapper'
	sudo apt-get -y install git
        sudo apt -y install \
                                                  libavahi-client-dev \
                                                  libconfig-dev \
                                                  libelf-dev \
                                                  libevent-dev \
                                                  libglib2.0-dev \
                                                  libnl-3-dev \
                                                  libnl-genl-3-dev \
                                                  libnotify-dev \
                                                  linux-headers-$(uname -r | sed 's/[0-9\.\-]*//') \
                                                  openssl \
                                                  qrencode \
						  libbluetooth-dev \
						  libgtk2.0-dev \
						  libgtk-3-dev \
						  libssl-dev \
						  make \
						  libpcap-dev \
						  libnet-dev \

        echo '[+] Packages Installed'
fi

echo ""
echo "(2/4) Installing ssa and ssa-daemon directories."
git clone https://github.com/markoneill/ssa
git clone https://github.com/markoneill/ssa-daemon
	echo "[+] ssa and ssa-daemon Installed Successful"

echo ""
echo "(3/4) Configuring ssa directory"
cd ssa
# These commands are mentioned in the README.md file that is in the ssa directory
#dnf -y install kernel-devel kernel-headers -> This is included in the package install
make
insmod ssa.ko
	echo "[+] Done"
cd ..

echo ""
echo "(4/4) Configuring ssa-daemon directory"
echo "[*] This my take a while"
cd ssa-daemon
rm rfcomm_* # Removing rfcom_client.c and rfcom_server.c files
# The following is the the build-client-auth.sh script in ssa-daemon edited
set -e

OPENSSL_INSTALL_DIR=$PWD/openssl
LIBEVENT_INSTALL_DIR=$PWD/libevent
SSLSPLIT_INSTALL_DIR=$PWD/sslsplit
TMP_DIR=$PWD/tmp

make clean

echo "rm -rf ${OPENSSL_INSTALL_DIR}"
rm -rf ${OPENSSL_INSTALL_DIR} || echo -e "\tfailed to remove file"
echo "rm -rf ${LIBEVENT_INSTALL_DIR}"
rm -rf ${LIBEVENT_INSTALL_DIR} || echo -e "\tfailed to remove file"
echo "rm -rf ${SSLSPLIT_INSTALL_DIR}"
rm -rf ${SSLSPLIT_INSTALL_DIR} || echo -e "\tfailed to remove file"
echo "rm -rf ${TMP_DIR}"
rm -rf ${TMP_DIR} || echo -e "\tfailed to remove file"
sleep 5

mkdir -p tmp
cd tmp

# we'll just clone it new every thme
#if [ ! -d "openssl" ] ; then
echo "Cloning OpenSSL repo"
git clone https://github.com/openssl/openssl.git
echo "Done"
#fi

echo "Applying OpenSSL patches"
cd openssl
git checkout tags/OpenSSL_1_1_1-pre3
git apply ../../extras/openssl/0001-Test-2.patch
#git apply ../../extras/openssl/0001-Adding-support-for-dynamic-client-authentication-cal.patch
echo "Done"
echo "Configuring OpenSSL"
mkdir -p $OPENSSL_INSTALL_DIR
./config --prefix=$OPENSSL_INSTALL_DIR --openssldir=$OPENSSL_INSTALL_DIR
echo "Done"
echo "Building OpenSSL"
make
echo "Done"
echo "Installing OpenSSL"
make install
cd ..
echo "Done"

echo "Downloading libevent source"
wget https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz -O libevent.tgz

echo "Done"
echo "Extracting libevent source"
mkdir -p libevent
tar xvf libevent.tgz -C libevent --strip-components 1
echo "Done"

echo "Configuring libevent"
cd libevent
mkdir -p $LIBEVENT_INSTALL_DIR
./configure CPPFLAGS="-I$OPENSSL_INSTALL_DIR/include" LDFLAGS="-L$OPENSSL_INSTALL_DIR/lib" --prefix=$LIBEVENT_INSTALL_DIR
echo "Done"
echo "Building libevent"
make
echo "Done"
echo "Installing libevent"
make install
cd ..
echo "Done"

cd ..
echo "Building Encryption Daemon"
make clientauth
echo "Done"

echo "Building custom sslsplit"
git clone https://github.com/droe/sslsplit
cd sslsplit
cp ../extras/sslsplit/0001-SSA-patch.patch .
cp ../extras/sslsplit/ca.crt .
cp ../extras/sslsplit/ca.key .
cp ../extras/sslsplit/start.sh .
cp ../extras/sslsplit/firewallOn.sh .
#git apply 0001-SSA-patch.patch
#cp -u /home/$USER/csci400/secure_socket_API/move_to_sslsplit_in_ssa-daemon/pxyconn.c . #This file have the patch done manually
cd ..
cd ..
dir=$PWD
cd ssa-daemon/sslsplit
cp -u $dir/move_to_sslsplit_in_ssa-daemon/pxyconn.c .
make
cd ..
make # This is for the ssa-daemon directory
echo "Done"

echo "Cleaning up"
#rm -rf tmp
echo "Done"
echo ""
echo ""
echo "[+] SSA installation Successful"
echo "[*] In order to start the TLS service, you must use './tls_wrapper' in the ssa-daemon directory"
echo ""
fi # end loop from (1/5)
