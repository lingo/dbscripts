#!/usr/bin/perl
use warnings;
use strict;

use DBI;
use Data::Dumper;
use Carp;
use Getopt::Std;

=head1 SYNOPSIS

Check a mySQL database, reporting any tables which don't have any indexes, or
which lack a PRIMARY_KEY

=head1 AUTHOR

Luke Hudson <lukeletters@gmail.com>

=cut

our $uniq = 1;
our %opt;

getopts('H:u:p:d:h', \%opt)
	or usage();
$opt{h} && usage();
$opt{d} || usage();
$opt{H} ||= 'localhost';

#print Dumper(\%opt);
my $mydb = DBI->connect("DBI:mysql:database=$opt{d};host=$opt{H}",
			$opt{u}, $opt{p},
			{RaiseError=>1, PrintError=>1}
		);

my $tables = $mydb->selectcol_arrayref(q{ SHOW TABLES });
#print Dumper(\$tables);

print "# SQL commands listed are suggestions only!\n";

for my $table (@$tables) {
	my $indexes = $mydb->selectall_hashref(qq{ SHOW INDEX FROM `$table` }, 'Key_name');
	unless($indexes) {
		print "** TABLE $table is missing indexes\n";
	} elsif (!$indexes->{PRIMARY}) {
		print "** TABLE $table is missing PRIMARY KEY\n";
		print "ALTER TABLE `$table` ADD PRIMARY KEY (id);\n";
	} else {
		print "# $table is OK\n";
	}
	## Look for *_id fields and check for FOREIGN KEY indexes (Specially for CakePHP)
	my $fields = $mydb->selectall_hashref(qq{ SHOW FIELDS FROM `$table` WHERE Field LIKE '%\\_id' }, 'Field');
	for my $field (keys %$fields) {
		my $guesstable = $field;
		$guesstable =~ s/_id//;
		$guesstable =~ s/y$/ies/g;
		$guesstable =~ s/([^s])$/$1s/g;
		unless ($indexes->{$field}) {
			print "** TABLE $table may be missing a foreign key for column $field\n";
			print "ALTER TABLE `$table` ADD FOREIGN KEY ($field) REFERENCES $guesstable (id);\n";
		}
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
