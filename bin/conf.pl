use PV::Local; my %MESSAGES = PV::Local::messages('conf');

die "$MESSAGES{non_param}\n$MESSAGES{aide}" unless @ARGV;

my $DIR = $ENV{PWD};
$DIR = dirname($DIR) until -e "$DIR/.pver" or ($DIR =~ /^\./ or !$DIR);
do "$DIR/.pver/conf.pl";

use Getopt::Long;
my $REF, $SERV; 
GetOptions ('ref|R:s' => \$REF, 'server|S' => \$SERV);
$REF ||= $CONF{defaultref} if $SERV; my $REFCFG = $CONF{ref}{$REF} if $REF;


while (my $id = shift) {
	my $val = shift;
	my $ref = \%CONF; $ref = $REFCFG if $REF;
	while ($id =~ s|^([\w\.]+)/||) {
		$$ref{$1} ||= {}; $ref = \%{$$ref{$1}};
	}
	$$ref{$id} = $val;
}

if ($SERV) { # mise à jour côté serveur
	use PV::Archive; my $arch = create PV::Archive (%$REFCFG);
	$arch->connect;
	unless ($arch->can_write ('sconf.pl')) {
		$arch->disconnect; 
		die $MESSAGES{non_autorise_serv};
	}
	if ($arch->exist ('sconf.pl')) {
		$arch->get ('sconf.pl', '.pver/sconf.pl');
		do '.pver/sconf.pl'; unlink '.pver/sconf.pl';
		$CONF{ref}{$REF}{serv} = \%SCONF;
	} else {
		$CONF{ref}{$REF}{serv} ||= {};
	}
	
	PV::Conf::ecrire ( %{$SERVCFG}, ".pver/sconf.pl", 'SCONF');
	$arch->put ('.pver/sconf.pl', 'sconf.pl'); # unlink '.pver/sconf.pl';
	$arch->disconnect;  
}
use PV::Conf; PV::Conf::ecrire (%CONF, "$DIR/.pver/conf.pl", 'CONF'); # Seulement si pas de die
