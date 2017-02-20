#!/bin/sh
export GOTCHA_LIB=/homes/dmamartin/bonsai/bin/newbuilder/NOBACK/go_svn/gotcha
export ORACLE_HOME=/sw/opt/oracle/instantclient_11_2
export LD_LIBRARY_PATH=/sw/opt/oracle/instantclient_11_2
export PERL5LIB=$PERL5LIB:$GOTCHA_LIB/lib:/sw/perl:/sw/lib64/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
qsub -v ORACLE_HOME=/sw/opt/oracle/instantclient_11_2 -v LD_LIBRARY_PATH=/sw/opt/oracle/instantclient_11_2 -v PATH=$PATH:/sw/local/bin:/bin -v GOTCHA_LIB=/homes/dmamartin/bonsai/bin/newbuilder/NOBACK/go_svn/gotcha -v PERL5LIB=$PERL5LIB:/homes/dmamartin/bonsai/bin/newbuilder/NOBACK/go_svn/gotcha/lib:/sw/perl:/sw/lib64/perl5/site_perl/5.8.8/x86_64-linux-thread-multi -o . -e . -cwd  ./foundbuilder.pl -dataroot $GOTCHA_LIB -taxa 10090,10116,148305,162425,167879,185431,195099,195103,198094,205920,208964,211586,212042,220664,222891,223283,227377,228405,243164,243231,243233,246194,264730,265669,3702,44689,4530,4896,4932,5476,562,5833,6239,666,7227,7955,9031,9606,9913
