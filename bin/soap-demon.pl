use SOAP::Transport::HTTP;
use Getopt::Long;
use PV::Serv::Soap;
use File::Basename;

my $PORT, $CONF, $ARCH, $LOGIN;
GetOptions (
	'port=i'	=> \$PORT,  'p=i' => \$PORT,
	'conf=s'    	=> \$CONF,  'c=s' => \$CONF,
	'archive=s' 	=> \$ARCH,  'a=s' => \$ARCH,
	'login=s'   	=> \$LOGIN, 'l=s' => \$LOGIN,
);
$PORT ||= 8080;

my $dir = dirname ($0);

PV::Serv::Soap->init (conf => $CONF, archive => $ARCH, login => $LOGIN)
	or die "Archive incorrecte ou non spécifiée\n";
unless ($ARCH) {
	$ARCH = $PV::Serv::Soap::ARCHIVE->{dir};
	$ARCH = "file:$ARCH" unless $ARCH =~ /^(\w+)(\+\w+)*\:/;
}

# don't want to die on 'Broken pipe' or Ctrl-C
  $SIG{PIPE} = $SIG{INT} = 'IGNORE';

  my $daemon = SOAP::Transport::HTTP::Daemon
    -> new (LocalPort => $PORT)
    -> dispatch_to($dir, 'PV::Serv::Soap')
  ;

  print "Contact to SOAP server at ", $daemon->url, " pid = $$, dir = $dir, Archive = $ARCH\n";
  $daemon->handle;

