#!/usr/bin/perl
use warnings;
use strict;

use DBI;
use Data::Dumper;
use Carp;
use Getopt::Std;

our $uniq = 1;
our %opt;
our $tableFilter;

our %inherit = ();
our $where   = '1=1';
our $limit   = '';


sub usage {
	print "$0  -H HOST -u USER -p PASS -d DATABASE -f OUTFILE [-T <LIKE>] [-I <INHERIT>] [-w <WHERE>] [-l <LIMIT>] [-D] [-s]\n";
	print "-l <LIMIT>   -- LIMIT clause for query, either a single integer, or format 'X OFFSET Y'\n";
	print "-w <FILTER>  -- WHERE clause for query (without WHERE keyword)\n";
	print "-T <LIKE>    -- only output tables whose names match LIKE expression\n";
	print "-I <INHERIT> -- table inheritance, espeically useful for SilverStripe/Sapphire\n";
	print "                this is a comma-separated list of  SUB:SUPER specifying that table SUB inherits from SUPER\n";
	print "                This assumes that SUB & SUPER use same value in ID column\n";
	print "-D			-- Debug mode, shows SQL\n";
	print "-s			-- Skip empty (NULL, or '') fields in output\n";
	die;
}


sub getArgs {
	getopts('H:u:p:d:f:hS:I:T:w:l:DP:sa', \%opt)
		or usage();
	$opt{h} && usage();
	$opt{d} || usage();
	#$opt{f} || usage();
	$opt{H} ||= 'localhost';
	$opt{S} ||= ''; #'/Applications/XAMPP/xamppfiles/var/mysql/mysql.sock';
	$tableFilter = $opt{T} || '';
	$tableFilter = "LIKE '$tableFilter'" if $tableFilter;
	if ($opt{I}) {
		for my $i (split(',', $opt{I})) {
			my ($c, $p) = split(':', $i);
			$inherit{$c} = $p;
		}
	}
	$where = $opt{w} || '1=1';
	if ($opt{l}) {
		$limit = "LIMIT $opt{l}";
	}

}

sub connectDB {
	#print Dumper(\%opt);
	my $mydb = DBI->connect("DBI:mysql:database=$opt{d};host=$opt{H};mysql_socket=$opt{S}",
				$opt{u}, $opt{p},
				{RaiseError=>1, PrintError=>0} #, mysql_enable_utf8 => 1}
			);

	my $sql = qq{SET NAMES 'utf8';};
	$mydb->do($sql);
	return $mydb;
}

sub getTables {
	my $mydb = $_[0]
		or croak "getTables requires mydb arg";
	my $tableFilter = $_[1]
		or croak "getTables requires tableFilter arg";

	my $tables = $mydb->selectcol_arrayref(qq{ SHOW TABLES $tableFilter});
	return $tables;
}
#print Dumper(\$tables);


my %assocToDump   = ();
my %assocIdLookup = ();

sub ydump {
	my ($table, $columns, $obj, $indent) = @_;
	our $uniq;
	$indent = ' ' x $indent;
	my $id = lc($table . $uniq);
	print "${indent}$id:\n";
	++$uniq;
	for my $k (sort keys %$obj) {
		my $v = $obj->{$k} || '';
		if ($opt{s} && ($v eq '' || not defined($v))) {
			next;
		}
		if ($opt{a} && $k =~ /\w+ID$/) {
			my $otherTable = $k;
			$otherTable =~ s/ID$//;
			if ($assocIdLookup{$otherTable}->{$v}) {
				$v = '=>' . $otherTable . '.' . $assocIdLookup{$otherTable}->{$v};
			}
		}
		if ($columns->{$k}->{Type} =~ /text/) {
			print "${indent}${indent}$k:   |\n";
			my @lines = split("\n", $v);
			print "${indent}${indent}${indent}$_\n" for @lines;
		} else {
			print "${indent}${indent}$k: $v\n";
		}
	}
	print "\n";
	return $id;
}


sub dumpAssociatedTable {
	my ($mydb, $keyName, $keyValue) = @_
		or croak 'dumpAssociated($mydb, $keyName, $keyValue) called with bad args';

	if (!$keyValue) {
		return;
	}
	# print "=> Dumping $keyName . $keyValue\n";
	my $table   = $keyName;

	my ($columns, $stm);

	eval { # try/catch for DB errors (non-existent table?)
		$columns = $mydb->selectall_hashref(qq{ DESC `$table` }, 'Field');
		$stm     = $mydb->prepare(qq{ SELECT `$table`.* FROM `$table` WHERE `$table`.`ID` = ? });
		$stm->execute($keyValue);
	};
	if ($@) {
		# carp $DBI::err, $@;
		return;
	}

	while (my $row = $stm->fetchrow_hashref()) {
		my $ymlID = ydump($table, $columns, $row, 4);
		$assocIdLookup{$table}->{$keyValue} = $ymlID;
	}
}

sub dumpAssociated {
	my ($mydb, $obj) = @_
		or croak 'dumpAssociated($mydb, $obj) called with bad args';

	for my $k (sort keys %$obj) {
		if ($k =~ /\w+ID$/) {
			my $table      = $k;
			$table =~ s/ID$//;
			$assocToDump{$table} ||= {};
			$assocToDump{$table}->{$obj->{$k}} = 1;
			$assocIdLookup{$table} ||= {};
			$assocIdLookup{$table}->{$obj->{$k}} = '';
		}
	}
	for my $keyName (sort keys %assocToDump) {
		my $items = grep { $_ != 0 } keys $assocToDump{$keyName};
		print "$keyName:\n" if $items;
		for my $keyValue (sort keys %{$assocToDump{$keyName}}) {
			# print "## Dump $keyName.$keyValue\n";
			dumpAssociatedTable($mydb, $keyName, $keyValue);
		}
	}
	# print Dumper(\%assocIdLookup);
}

sub dumpData {
	my ($mydb, $tables) = @_
		or croak "dumpData(\$mydb, \$tables) called badly";

	for my $table (@$tables) {
		# my $cols = $mydb->selectall_hashref(qq{ DESC `$table` }, 'Field');
		# my $vstr = '?,' x scalar keys %$cols;
		# $vstr =~ s/,$//;
		# my @cols = sort keys %$cols;
		# my $cstr = join(',', map { qq|"$_"| } @cols);
		#print Dumper($vstr);

		my $columns = $mydb->selectall_hashref(qq{ DESC `$table` }, 'Field');
		my $count = $mydb->selectrow_array(qq{ SELECT COUNT(*) FROM `$table` });
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
		my @rows = ();
		while (my $row = $stm->fetchrow_hashref()) {
			if ($opt{a}) {
				dumpAssociated($mydb, $row);
			}
			push @rows, $row;
		}
		if ($count) {
			print "\n$table:\n";
		}
		for my $row (@rows) {
			ydump($table, $columns, $row, 4);
		}
	}
}

getArgs();
my $mydb   = connectDB();
my $tables = getTables($mydb, $tableFilter);
dumpData($mydb, $tables);