use PV::Archive;
use Getopt::Long;
use PV::Conf;
use PV::Archive;
use IO::Socket;


my ($REF, $NOM);
GetOptions (
	'ref:s' => \$REF, 'R:s' => \$REF,
	'sockname:s' => \$NOM, 'S:s' => \$NOM
);
my ($DIR) = &PV::Conf::basedir(); do "$DIR/.pver/conf.pl";
$REF ||= $CONF{defaultref}; my $REFCFG = $CONF{ref}{$REF}; my $REFDIR = "$DIR/.pver/$REF";
$NOM = "/tmp/pver_conn-serv.$<" if $NOM eq 'user'; $NOM ||= "$REFDIR/conn-serv";

my $arch = create PV::Archive (%$REFCFG); $arch->connect() or die "Impossible de se connecter au référentiel $REF\n";

unlink "$REFDIR/conn-serv";
my $server = IO::Socket::UNIX->new (Local => $NOM, Type => SOCK_DGRAM, Listen => 5)
		or die "Impossible de créer le serveur (sock = $NOM) : '$@'.\n";

print "Ouverture serveur, addresse = $NOM, serveur = $server\n";
use Data::Dumper; print Dumper ($server); 
while ($commande_str = $server->recv ($msg, 1024)) {
	print "'$commande_str'\n"; next;
		my ($commande, @args) = split (/\s/, $commande_str);
		my @res = $arch->$commande (@args);
		print $client scalar(@res, "\n");
		print $client @res;
}

=for later
while ($client = $server->accept()) {
	print "Client accepte : $client\n";
	while (my $commande_str = <$client>) {
		my ($commande, @args) = split (/\s/, $commande_str);
		my @res = $arch->$commande (@args);
		print $client scalar(@res, "\n");
		print $client @res;
	}
}
=cut
