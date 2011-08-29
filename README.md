# dbscripts #

Some scripts to dump  / convert between CSV, MySQL, SQLite and YAML

## Usage ##

### CSV to SQLite ###

Import a CSV file or a bunch of them into a new SQLite3 DB.
This is not particularly clever, just creates tables based on the header rows,
and treats everything as VARCHAR.

However, it can be handy if you have a lot of CSV files to analyse and compare.

*Usage:* `./csv2sqlite.pl file.db [ file.csv file.csv ...]`
Input CSV files default to *.csv if not supplied on commandline

### MySQL 2 YAML ###

Dumps MySQL database to YAML.  Originally written to make creation of SilverStripe test fixtures easy.

#### Example output ####

    BlogHolder:
        blogholder5:
            ID: 4
            LandingPageFreshness: 
            Name: 
            SideBarID: 1
            TrackBacksEnabled: 


    BlogHolder_Live:
        blogholder_live6:
            ID: 4
            LandingPageFreshness: 
            Name: 
            SideBarID: 1
            TrackBacksEnabled: 

*Usage:* `./my2yml.pl  -H HOST -u USER -p PASS -d DATABASE > OUTFILE`

### SQLite to YAML ###

Similar to above, but for SQLite.

*Usage:* `./sqlite2yml.pl  -d DATABASE.db > OUTFILE`

### MySQL to SQLite ###

Attempts to convert MySQL database to SQLite..  Very simplistic.

*Usage:* `my2sqlite.pl  -H HOST -u USER -p PASS -d DATABASE -s SQLITEFILE`