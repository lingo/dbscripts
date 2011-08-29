#!/opt/local/bin/perl
use warnings;
use strict;

use DBI;
use Data::Dumper;
use Carp;
use Getopt::Std;

# Scan command line arguments.
our %opt;

getopts('H:u:p:d:s:S:h', \%opt)
	or usage();

# Show usage if -h was passed
$opt{h} && usage();

# Set default options if not passed from command line
$opt{d} || usage();
$opt{s} || usage();
$opt{H} ||= 'localhost';
$opt{S} ||= '/Applications/XAMPP/xamppfiles/var/mysql/mysql.sock';

#print Dumper(\%opt);

my $mydb = DBI->connect("DBI:mysql:database=$opt{d};host=$opt{H};mysql_socket=$opt{S}",
			$opt{u}, $opt{p},
			{RaiseError=>1, PrintError=>1}
		);

my $sqlitedb = DBI->connect("DBI:SQLite:dbname=$opt{s}",
			'', '',
			{AutoCommit => 0, RaiseError => 1, PrintError => 1});


# Get list of tables from MySQL DB
my $tables = $mydb->selectcol_arrayref(q{ SHOW TABLES });
print Dumper(\$tables);

# Loop through MySQL tables
for my $table (@$tables) {
	# Get table fields from MySQL DESC statement
	my $cols = $mydb->selectall_hashref(qq{ DESC `$table` }, 'Field');
	# Create the parameter string for SQL
	my $vstr = '?,' x scalar keys %$cols;
	$vstr =~ s/,$//; # Remove final ','
	my @cols = sort keys %$cols; # Sort table fields by name
	# Quote each field name and join them with commas
	my $cstr = join(',', map { qq|"$_"| } @cols); 
	#print Dumper($vstr);

	my $stm = $mydb->prepare(qq{ SELECT * FROM `$table` ORDER BY ID });
	# !!Clear SQLite DB table!!
	$sqlitedb->do(qq{ DELETE FROM "$table" });
	# Use prepared statement string constructed in previous block
	print qq{ INSERT INTO "$table" ($cstr) VALUES($vstr) \n};
	my $inStm = $sqlitedb->prepare(qq{ INSERT INTO "$table" ($cstr) VALUES($vstr) });
	$stm->execute();
	# Look through all rows, inserting data from MySQL results into SQLite.
	while (my $row = $stm->fetchrow_hashref()) {	
		print Dumper(\$row);
		for (my $i=1; $i <= @cols; $i++) {
			$inStm->bind_param($i, $row->{$cols[$i-1]});
		}
		$inStm->execute();
	}
	$sqlitedb->commit();
}

sub usage {
	print "$0  -H HOST -u USER -p PASS -d DATABASE -s SQLITEFILE\n";
	die;
}
