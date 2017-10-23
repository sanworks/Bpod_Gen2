#! /usr/bin/perl -w
#

if ( $#ARGV < 0 or $#ARGV>=1 or  ( $#ARGV==0  and  
			($ARGV[0] eq "--help" or $ARGV[0] eq "-h" 
			 or $ARGV[0] eq "-help" )) ) {
  print "\n";
  print "Usage: kill_by_name.pl name\n";
  print "\n";
  print "  Does repeated calls of ps -axwu and kills -9 any processes\n";
  print "  with a name matching the passed name.\n";
  print "\n";
  exit(1);
}



$output = `ps -axwu | grep $ARGV[0] | grep -v grep | grep -v kill_by_name.pl`;
# print $output . "\n";


($trash1, $pid) = split(' ', $output);

while ( $pid ) {
  # print "Want to kill PID " . $pid . "\n";
  system("kill -9 " . $pid);
  # print "kill_by_name.pl:  killed -9 process " . $pid . "\n";

  $output = `ps -axwu | grep $ARGV[0] | grep -v grep |grep -v kill_by_name.pl`;
  ($trash1, $pid) = split(' ', $output);
}

