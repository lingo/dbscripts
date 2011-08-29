#!/usr/bin/perl

=head1 SYNPOSIS

Import a CSV file or a bunch of them into a new SQLite3 DB.
This is not particularly clever, just creates tables based on the header rows,
and treats everything as VARCHAR.

However, it can be handy if you have a lot of CSV files to analyse and compare.

=head1 AUTHOR

Luke Hudson <lukeletters@gmail.com>

=cut

use 5.10.0; # Enable newer perl features such as 'say'
use warnings;
use strict;
use Data::Dumper;
use Carp;

use DBI;
use Text::CSV;

if (@ARGV < 1) {
	say "Usage: $0 file.db [ file.csv file.csv ...]";
	say "Input CSV files default to *.csv if not supplied on commandline";
	exit 1;
}

our $dbfile = shift @ARGV;
our $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","")
	or croak $!;
our $csv = Text::CSV->new;


my @headers;

sub init_table {
	my ($tableName, $headers) = @_ or croak "init_table called without headers";
	$tableName =~ s/(.*)\.[^.]*$/$1/;

	my $colDef = join(', ', map {"\"$_\" VARCHAR(255)"} @headers);
	my $sql = qq{CREATE TABLE "$tableName" (${tableName}_id INTEGER PRIMARY KEY, $colDef)};
	print "$sql\n";
	$dbh->do($sql);
	$dbh->commit();

	my $params = '?,' x scalar @headers;
	chop($params);
	$colDef = '"' . join('", "', @headers) . '"';
	$sql = qq{ INSERT INTO "$tableName" ($colDef) VALUES ($params) };
	print "$sql\n";
	return $dbh->prepare($sql);
}

my @files = @ARGV;
@files = <*.csv> unless @files;

FILE: for my $fname (@files) {
	local $| = 1;# Flush	

	print "LOAD $fname\n";
	open CSV, '<', $fname
		or croak "$!";

	my $sth;
	@headers = ();
	LINE: while(<CSV>) {
		last LINE unless $csv->parse($_);
		my @columns = $csv->fields();
		unless (@headers) {
			@headers = @columns;
			print join(' | ', @headers) . "\n";
			$sth = init_table($fname, \@headers);
			next LINE;
		}
		croak "No statement!" unless $sth;
		$sth->execute(@columns);
		print '.';
	}
	close CSV;
	$dbh->commit();
}

$dbh->disconnect();
