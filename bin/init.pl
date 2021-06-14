use Getopt::Long;

my ($ARCHIVE, $PROJET, $BRANCHE, $LOGIN, $REF);
# getopts ('a:p:b:l:', \%OPT);
GetOptions (
	'archive|a=s' => \$ARCHIVE, 
	'projet|p=s' => \$PROJET,  'branche|b:s' => \$BRANCHE, 
	'login|l:s' => \$LOGIN, 
	'ref|R:s' => $REF, 
);

use PV::Local; my %MESSAGES = PV::Local::messages('init');

$REF ||= shift || 'Ref0'; $ARCHIVE ||= shift; $PROJET ||= shift; $BRANCHE ||= shift || 'base'; $LOGIN ||= shift;
unless ($ARCHIVE and $PROJET) {
	die "$MESSAGES{non_param}\n$MESSAGES{syntaxe}";
}

unless (-e '.pver') {
	mkdir ".pver" or die "\n";
}
do '.pver/conf.pl' if -e '.pver/conf.pl';
mkdir ".pver/$REF"; $CONF{defaultref} = $REF;
$CONF{ref}{$REF} ||= {
	archive => $ARCHIVE, projet => $PROJET, login => $LOGIN, branche => $BRANCHE,
	unit => {
		# global => [ $BRANCHE, 0 ]
	}
};

use PV::Archive;
my $arch = create PV::Archive (archive => $ARCHIVE, projet => $PROJET, branche => $BRANCHE, login => $LOGIN);
$arch->connect;
if ($arch->exist ('sconf.pl')) {
	$arch->get ('sconf.pl', '.pver/sconf.pl');
	do '.pver/sconf.pl'; unlink '.pver/sconf.pl';
	$CONF{ref}{$REF}{serv} = \%SCONF;
}
$arch->disconnect;

use PV::Conf; PV::Conf::ecrire ( %CONF, '.pver/conf.pl', 'CONF');
