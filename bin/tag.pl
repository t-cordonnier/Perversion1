use Getopt::Long;

my %OPT = map { ($_ => undef) } qw(n r b R U);
GetOptions (
	'nom:s' => \$OPT{n}, 'n:s' => \$OPT{n},
	'ver:s' => \$OPT{v}, 'v:s' => \$OPT{v},
	'branche:s' => \$OPT{b}, 'b:s' => \$OPT{b},
	'ref:s' => \$OPT{R}, 'R:s' => \$OPT{R},
	'unit:s' => \$OPT{U}, 'U:s' => \$OPT{U},
);

unless (@ARGV || $OPT{n}) {
	local $/ = undef; die <DATA>;
}

my $DIR = $ENV{PWD};
while (! -e "$DIR/.pver") {
	my $idx = rindex ($DIR, '/');
	if ($idx < 1) {
		die "Impossible de retrouver le répertoire de base";
	}
	$DIR = substr($DIR, 0, $idx);
}


do '.pver/conf.pl';
my $REF = $OPT{R} ||= $CONF{defaultref}; my $REFCONF = $CONF{ref}{$REF};
my $archive = $$REFCONF{archive} or die "Archive non déclarée (référentiel $REF)\n";
my $projet = $$REFCONF{projet} or die "Projet non déclaré (référentiel $REF)\n";
my $tag = $OPT{n} || shift;
my $unite = $OPT{U} || shift || '*';
my $revision = $OPT{r} || shift;
my $branche = $OPT{b} || shift;

my $MSG = $tag . "\t";
my @UNITES = ();
unless ($unite eq '*') { @UNITES = split (/,/, $unite); } else { @UNITES = keys (%{$$REFCONF{unit}}); }
foreach $unite (@UNITES) {
	my $UNITCFG = $$REFCONF{unit}{$unite};
	my $br0 = $branche || $$UNITCFG[0]; my $rev0 = $revision || $$UNITCFG[1];
	$MSG .= "$unite:$br0:$rev0\t";
}

use PV::Archive;
my $arch = create PV::Archive (%$REFCONF);
$arch->connect ();
$arch->ajoute ("$projet/tags", $MSG . "\n");
print "$projet/tags : $MSG\n";
$arch->disconnect;


