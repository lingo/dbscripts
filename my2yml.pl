#!/usr/bin/perl
use warnings;
use strict;

use DBI;
use Data::Dumper;
use Carp;
use Getopt::Std;

our $uniq = 1;
our %opt;

getopts('H:u:p:d:f:hS:I:T:w:l:D', \%opt)
	or usage();
$opt{h} && usage();
$opt{d} || usage();
#$opt{f} || usage();
$opt{H} ||= 'localhost';
$opt{S} ||= ''; #'/Applications/XAMPP/xamppfiles/var/mysql/mysql.sock';

#print Dumper(\%opt);
my $mydb = DBI->connect("DBI:mysql:database=$opt{d};host=$opt{H};mysql_socket=$opt{S}",
			$opt{u}, $opt{p},
			{RaiseError=>1, PrintError=>1}
		);

my $tableFilter = $opt{T} || '';
$tableFilter = "LIKE '$tableFilter'" if $tableFilter;
my $tables = $mydb->selectcol_arrayref(qq{ SHOW TABLES $tableFilter});
#print Dumper(\$tables);

my %inherit = ();
if ($opt{I}) {
	for my $i (split(',', $opt{I})) {
		my ($c, $p) = split(':', $i);
		$inherit{$c} = $p;
	}	
}

my $where = $opt{w} || '1=1';
my $limit = '';
if ($opt{l}) {
	$limit = "LIMIT $opt{l}";
}

for my $table (@$tables) {
	# my $cols = $mydb->selectall_hashref(qq{ DESC `$table` }, 'Field');
	# my $vstr = '?,' x scalar keys %$cols;
	# $vstr =~ s/,$//;
	# my @cols = sort keys %$cols;
	# my $cstr = join(',', map { qq|"$_"| } @cols);
	#print Dumper($vstr);

	my $columns = $mydb->selectall_hashref(qq{ DESC `$table` }, 'Field');
	my $count = $mydb->selectrow_array(qq{ SELECT COUNT(*) FROM `$table` });
	if ($count) {
		print "\n$table:\n";
	}
	my $sql = '';
	if ($inherit{$table}) {
		my $t2 = $inherit{$table};
		$sql = qq{ SELECT `$table`.*, `$t2`.* FROM `$table` LEFT JOIN `$t2` ON `$t2`.ID=`$table`.ID WHERE $where ORDER BY `$table`.ID $limit };
	} else {
		$sql = qq{ SELECT * FROM `$table` WHERE $where ORDER BY `$table`.ID $limit };
	}
	if ($opt{D}) {
		print $sql. "\n";
	}
	my $stm = $mydb->prepare($sql);
	$stm->execute();
	while (my $row = $stm->fetchrow_hashref()) {	
		ydump($table, $columns, $row, 4);
	}
}

sub usage {
	print "$0  -H HOST -u USER -p PASS -d DATABASE -f OUTFILE [-T <LIKE>] [-I <INHERIT>] [-w <WHERE>] [-l <LIMIT>]\n";
	print "-l <LIMIT>   -- LIMIT clause for query, either a single integer, or format 'X OFFSET Y'\n";
	print "-w <FILTER>  -- WHERE clause for query (without WHERE keyword)\n";
	print "-T <LIKE>    -- only output tables whose names match LIKE expression\n";
	print "-I <INHERIT> -- table inheritance, espeically useful for SilverStripe/Sapphire\n";
	print "                this is a comma-separated list of  SUB:SUPER specifying that table SUB inherits from SUPER\n";
	print "                This assumes that SUB & SUPER use same value in ID column\n";
	die;
}



sub ydump {
	my ($table, $columns, $obj, $indent) = @_;
	our $uniq;
	$indent = ' ' x $indent;
	print "${indent}\L$table$uniq:\n";
	++$uniq;
	for my $k (sort keys %$obj) {
		my $v = $obj->{$k} || '';
		if ($columns->{$k}->{Type} =~ /text/) {
			print "${indent}${indent}$k:   |\n";
			my @lines = split("\n", $v);
			print "${indent}${indent}${indent}$_\n" for @lines;
		} else {		
			print "${indent}${indent}$k: $v\n";
		}
	}
	print "\n";
}
