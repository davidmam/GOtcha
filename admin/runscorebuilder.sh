#!/bin/sh
export GOTCHA_LIB=/homes/dmamartin/bonsai/bin/newbuilder/NOBACK/go_svn/gotcha
export ORACLE_HOME=/sw/opt/oracle/instantclient_11_2
export LD_LIBRARY_PATH=/sw/opt/oracle/instantclient_11_2
export PERL5LIB=$PERL5LIB:$GOTCHA_LIB/lib:/sw/perl:/sw/lib64/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
qsub -v ORACLE_HOME=/sw/opt/oracle/instantclient_11_2 -v LD_LIBRARY_PATH=/sw/opt/oracle/instantclient_11_2 -v PATH=$PATH:/sw/local/bin:/bin -v GOTCHA_LIB=/homes/dmamartin/bonsai/bin/newbuilder/NOBACK/go_svn/gotcha -v PERL5LIB=$PERL5LIB:/homes/dmamartin/bonsai/bin/newbuilder/NOBACK/go_svn/gotcha/lib:/sw/perl:/sw/lib64/perl5/site_perl/5.8.8/x86_64-linux-thread-multi -o . -e . -cwd ./scorebuilder.pl -scoresall ../calibration/calibration_all -scoresnoiea ../calibration/calibration_noiea
