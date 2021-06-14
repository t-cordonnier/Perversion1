use Getopt::Long;
use PV::Serv;

our ($NOM, $REF, $COPIE, $UNITE, $TYPE);
{
	my ($PARA, $ISOL, $DERIV); 
	GetOptions (
		'nom|n=s' => \$NOM,  'type|T:s' => \$TYPE, 
		'para|p' => \$PARA,  'isol|i' => \$ISOL, 'deriv|d' => \$DERIV, 
	# 	'copie:s' => \$COPIE, 'c:s' => \$COPIE,
		'ref|R:s' => \$REF, 
		'unit|U:s' => \$UNITE, 
	);
	$TYPE = 'para' if $PARA; $TYPE = 'isol' if $ISOL; $TYPE = 'deriv' if $DERIV;
}

unless (@ARGV || $NOM) {
	local $/ = undef; die <DATA>;
}

my $DIR = $ENV{PWD};
while (! -e "$DIR/.pver") {
	my $idx = rindex ($DIR, '/');
	if ($idx < 1) {
		require PV::Local; my %MESSAGES = PV::Local::messages ('branch');
		die $MESSAGES{non_base};
	}
	$DIR = substr($DIR, 0, $idx);
}


do '.pver/conf.pl';
my $REF = $REF ||= $CONF{defaultref}; my $REFCONF = $CONF{ref}{$REF};
my @UNITES = (); if ($UNITE) { @UNITES = split (/,/, $UNITE); } else { @UNITES = keys (%{$$REFCONF{unit}}); }

my $projet = $$REFCONF{projet}; my $brancheDest = $NOM;
my $EXT = $$REFCONF{serv}{format}; $EXT = ".$EXT" if $EXT;
use PV::Archive;
my $arch = create PV::Archive (%$REFCONF);
$arch->connect ();
my %EV = PV::Serv::evenements (%$REFCONF, aref => $arch); my $EVSTR;
foreach my $unite (@UNITES) {
	my $UNITCFG = $$REFCONF{unit}{$unite}; my $brancheOrig = $$UNITCFG[0]; $$UNITCFG[0] = $brancheDest;
	my $origDir = "$projet/$unite/$brancheOrig"; my $destDir = "$projet/$unite/$brancheDest";
	print STDERR "$origDir --> $destDir\n" if $CONF{trace}; 
	$arch->makedir ($destDir);
	if ($TYPE eq 'para') { # branche parall�e
		$arch->sLink ("$origDir/1-cache$EXT", "$destDir/1-cache$EXT");
		$EVSTR .= join("\t", $EV{$unite}{$brancheOrig}[1], $unite, $brancheDest, 1) . "\n";
		for (my $i = 2; $i <= $$UNITCFG[1]; $i++) {
			$arch->sLink ("$origDir/$i$EXT", "$destDir/$i$EXT");
			$EVSTR .= "$EV{$unite}{$brancheOrig}[$i]\t$unite\t$brancheDest\t$i\n";
		}
		$arch->pLink ("$origDir/$$UNITCFG[1]-cache$EXT", "$destDir/$$UNITCFG[1]-cache$EXT");
		$arch->copie ("$origDir/log", "$destDir/log");
	} elsif ($TYPE eq 'deriv') { # branche d�iv�
		$arch->pLink ("$origDir/$$UNITCFG[1]-cache$EXT", "$destDir/1-cache$EXT");
		$$UNITCFG[1] = 1; # changement de num�otation
		$EVSTR .= join("\t", $EV{$unite}{$brancheOrig}[$$UNITCFG[1]], $unite, $brancheDest, 1) . "\n";
	} elsif ($TYPE eq 'isol') {
		$$UNITCFG[1] = 0; # premier commit --> premi�e version
	} else {
		require PV::Local; my %MESSAGES = PV::Local::messages ('branch');		
		if ($TYPE) { die "$MESSAGES{mauv_type} ($TYPE)"; }
		else { die $MESSAGES{manque_type}; }
	}
}
$arch->ajoute ("$projet/ev", $EVSTR);
$arch->disconnect;

PV::Conf::ecrire ( %CONF, "$DIR/.pver/conf.pl", 'CONF');
