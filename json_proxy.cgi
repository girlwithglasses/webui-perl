#!/bin/bash
# Control the environment from here for security and other reasons.
#PATH=""
#export PATH
#LD_LIBRARY_PATH="/opt/oracle/lib:/usr/local/lib"; export LD_LIBRARY_PATH

#/usr/local/bin/perl -I`pwd` -T json_proxy.pl
#/usr/common/usg/languages/perl/5.16.0/bin/perl -I`pwd` -T  json_proxy.pl

PERL5LIB=`pwd`
export PERL5LIB
/webfs/projectdirs/microbial/img/bin/imgPerlEnv perl -T json_proxy.pl

if [ $? != "0" ]
then
   echo "<font color='red'>"
   echo "Oops. This is embarrassing an error has occurred in our JSON script."
   echo "Please reports this along with your steps on how to reproduce it."
   echo "- IMG email: imgsupp at lists.jgi-psf.org"
   echo "</font>"
fi
