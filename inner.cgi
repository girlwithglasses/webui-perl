#!/bin/bash 
# Control the environment from here for security and other reasons.
#PATH=""
#export PATH
#/usr/common/usg/languages/perl/5.16.0/bin/perl -I`pwd` -T inner.pl

PERL5LIB=`pwd`
export PERL5LIB
/webfs/projectdirs/microbial/img/bin/imgPerlEnv perl -T inner.pl

if [ $? != "0" ] 
then
   echo "<font color='red'>"
   echo "ERROR: Perl taint (-T) security violation or other error." 
   echo "Check web server error log for details."
   echo "</font>"
fi
