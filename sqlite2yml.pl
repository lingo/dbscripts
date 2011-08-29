#!/usr/bin/perl
use warnings;
use strict;

use DBI;
use Data::Dumper;
use Carp;
use Getopt::Std;

our $uniq = 1;
our %opt;

getopts('d:f:hS:', \%opt)
	or usage();
$opt{h} && usage();
$opt{d} || usage();
#$opt{f} || usage();

#print Dumper(\%opt);
my $mydb = DBI->connect("DBI:SQLite:dbname=$opt{d}",
			'','',
			{RaiseError=>1, PrintError=>1}
		);

# SQL below from http://stackoverflow.com/questions/82875/how-do-i-list-the-tables-in-a-sqlite-database-file
my $tables = $mydb->selectcol_arrayref(q{
	SELECT name FROM sqlite_master 
	WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%'
	UNION ALL 
	SELECT name FROM sqlite_temp_master 
	WHERE type IN ('table','view') 
	ORDER BY 1
});
#print Dumper(\$tables);

for my $table (@$tables) {
	my $cols = $mydb->selectall_hashref(qq{ PRAGMA table_info("$table")	}, 'name');
	my $vstr = '?,' x scalar keys %$cols;
	$vstr =~ s/,$//;
	my @cols = sort keys %$cols;
	my $cstr = join(',', map { qq|"$_"| } @cols);
	#print Dumper($vstr);

	my $count = $mydb->selectrow_array(qq{ SELECT COUNT(*) FROM "$table" });
	if ($count) {
		print "\n$table:\n";
	}
	my $stm = $mydb->prepare(qq{ SELECT * FROM "$table" ORDER BY ID });
	$stm->execute();
	while (my $row = $stm->fetchrow_hashref()) {	
		ydump($table, $row, 4);
	}
}

sub usage {
	print "$0  -d DATABASE.db -f OUTFILE\n";
	die;
}



sub ydump {
	my ($table, $obj, $indent) = @_;
	our $uniq;
	my $pfx = ' ' x $indent;
	print "$pfx\L$table$uniq:\n";
	++$uniq;
	for my $k (sort keys %$obj) {
		my $v = $obj->{$k} || '';
		print "$pfx$pfx$k: $v\n";
	}
	print "\n";
}
