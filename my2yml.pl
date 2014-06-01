#!/usr/bin/perl
use warnings;
use strict;

use DBI;
use Data::Dumper;
use Carp;
use Getopt::Std;

our $uniq = 1;
our %opt;

getopts('H:u:p:d:f:hS:T:w:', \%opt)
	or usage();
$opt{h} && usage();
$opt{d} || usage();
#$opt{f} || usage();
$opt{H} ||= 'localhost';
$opt{S} ||= '';

#print Dumper(\%opt);
my $mydb = DBI->connect("DBI:mysql:database=$opt{d};host=$opt{H};mysql_socket=$opt{S}",
			$opt{u}, $opt{p},
			{RaiseError=>1, PrintError=>1}
		);

my $tfilter = '';
if ($opt{T}) {
	$tfilter = qq| LIKE '$opt{T}' |;
#print $tfilter;
}

my %wheres = ();
if ($opt{w}) {
	my @whereClauses = split(';', $opt{w});
	for my $wpair (@whereClauses) {
		my ($table, $where) = split(':', $wpair);
		if ($where !~ /where/i) {
			$where = 'WHERE '. $where;
		}
		$wheres{$table} = $where;
	}
#print Dumper(\%wheres);
}

my $tables = $mydb->selectcol_arrayref(qq{ SHOW TABLES $tfilter });
#print Dumper(\$tables);

for my $table (@$tables) {
	my $where = $wheres{$table} || '';
	#print "$table, $where :::: \n";
	my $cols = $mydb->selectall_hashref(qq{ DESC `$table` }, 'Field');
	my $vstr = '?,' x scalar keys %$cols;
	$vstr =~ s/,$//;
	my @cols = sort keys %$cols;
	my $cstr = join(',', map { qq|"$_"| } @cols);
	#print Dumper($vstr);

	my $count = $mydb->selectrow_array(qq{ SELECT COUNT(*) FROM `$table` $where });
	if ($count) {
		print "\n$table:\n";
	}
	my $stm = $mydb->prepare(qq{ SELECT * FROM `$table` $where ORDER BY ID });
	$stm->execute();
	while (my $row = $stm->fetchrow_hashref()) {	
		ydump($table, $row, 4);
	}
}

sub usage {
	print "$0  -H HOST -u USER -p PASS -d DATABASE -f OUTFILE\n";
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
