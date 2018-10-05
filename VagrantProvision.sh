#!/bin/bash

# This script should NOT be run as root. It was developed on Ubuntu Xenial

# When this script is run on a VM or Linux host, it will:
#   Install everything necessary for the VM or host (if the host is compatible)
#   Update everything necessary for the VM or host

cd $( dirname "${BASH_SOURCE[0]}" )

if [ -e /vagrant/Vagrant.pl ]; then VCODE="/vagrant"; else VCODE=`pwd`; fi
if [ ! -e $HOME/.osis-converters/src ]; then mkdir -p $HOME/.osis-converters/src; fi

sudo apt-get update
sudo apt-get install -y build-essential cmake libtool libtool-bin autoconf make pkg-config libicu-dev unzip cpanminus subversion git gitk zip swig libxml-libxml-perl zlib1g-dev default-jre libsaxonb-java libxml2-dev libxml2-utils liblzma-dev dos2unix epubcheck

# XML::LibXML
sudo cpanm XML::LibXML::PrettyPrint
sudo cpanm HTML::Entities

# Calibre
if [ ! `which calibre` ]; then
  sudo apt-get install -y xorg openbox
  sudo apt-get install -y xdg-utils imagemagick python-imaging python-mechanize python-lxml python-dateutil python-cssutils python-beautifulsoup python-dnspython python-poppler libpodofo-utils libwmf-bin python-chm
  # the .config directory must be created now, or else the calibre installer creates it as root making it unusable by vagrant
  mkdir $HOME/.config
  sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
fi
calibre-customize -b $VCODE/calibre_plugin/OSIS-Input

# GoBible Creator
if [ ! -e  $HOME/.osis-converters/GoBibleCreator.245 ]; then
  cd $HOME/.osis-converters
  wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/gobible/GoBibleCreator.245.zip
  unzip GoBibleCreator.245.zip
  rm GoBibleCreator.245.zip
fi

# Module-tools
if [ ! -e $HOME/.osis-converters/src/Module-tools/.git ]; then
  cd $HOME/.osis-converters/src
  if [ -e ./Module-tools ]; then
    rm -rf ./Module-tools
  fi
  git clone https://github.com/JohnAustinDev/Module-tools.git
else
  cd $HOME/.osis-converters/src/Module-tools
  git stash
  git checkout master
  git pull
fi

# SWORD 1.8 from subversion
swordRev=3595
if [ ! -e $HOME/.osis-converters/src/sword ]; then
  svnrev=0
else
  cd $HOME/.osis-converters/src/sword
  svnrev=`svnversion`
fi

# Build Sword tools and install Perl bindings
if [ ${svnrev:0:${#swordRev}} != "$swordRev" ]; then
  cd $HOME/.osis-converters/src
  svn checkout -r $swordRev http://crosswire.org/svn/sword/trunk sword
  mkdir sword/build
  cd sword
  
  # The setFormattedVA function caused perlswig build to fail and isn't needed
  perl -0777 -pe 's/(charAt\(unsigned long\);)/$1\n%ignore sword::SWBuf::setFormattedVA(const char *format, va_list argptr);/' ./bindings/swig/swbuf.i > swbuf.i
  mv swbuf.i ./bindings/swig/swbuf.i
  # fix xml2gbs.cpp bug that disallows '.' in GenBook keys
  sed -i -r -e "s|else if \(\*strtmp == '\.'\)|else if (*strtmp == 34)|" ./utilities/xml2gbs.cpp
  # fix osis2mod bug that drops paragraph type when converting to milestone div
  # fix osis2mod bug that puts New Testament intro at end of Malachi
  # fix osis2mod bug that fails to treat subSection titles as pre-verse titles
  cp "$VCODE/sword-patch/osis2mod.cpp" "$HOME/.osis-converters/src/sword-svn/utilities/"
  
  cd build
  cmake -G "Unix Makefiles" -D SWORD_BINDINGS=Perl ..
  make
  
  # Install Perl Sword bindings
  cd bindings/swig/perl
  rm Makefile
  mv Makefile.perlswig Makefile
  make
  sudo make install
fi

# non English hosts may need this:
sudo su -c "echo LC_ALL=en_US.UTF-8 >> /etc/environment"
sudo su -c "echo LANG=en_US.UTF-8 >> /etc/environment"

