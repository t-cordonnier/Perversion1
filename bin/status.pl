use Getopt::Std;

my %OPT;
getopts ('CSFR:B:', \%OPT);

my $PWD = $ENV{PWD}, $prefix = '';
while (! -e ".pver") {
	die "Impossible de trouver le répertoire racine" if $ENV{PWD} eq '/';
	my $idx = rindex($PWD,'/'); my $ap = substr($PWD, $idx + 1);
	$prefix = "$ap/$prefix"; chdir '..'; $PWD = substr($PWD,0, $idx);
}
$prefix ||= '.';

do "$PWD/.pver/conf.pl"; my $REF = $OPT{R} || $CONF{defaultref};
my $REFCFG = $CONF{ref}{$REF};

if ($OPT{S} || !($OPT{C})) { # charger la configuration serveur
	require PV::Serv; %EV = PV::Serv::evenements (%$REFCFG);
}

while (my ($ent, $client) = each (%{$CONF{ref}{$REF}{unit}})) {
	if ($OPT{C} && !($OPT{S})) { # client uniquement
		print "\t$ent ==> $$client[0]:$$client[1]\n";
	} elsif ($OPT{S} && !($OPT{C})) { # serveur uniquement
		my $EntEv = $EV{$ent};
		print "\t$ent : "; print "\n" if scalar(keys(%$EntEv)) > 1;
		while (my ($BR, $REF2) = each (%$EntEv)) {
			my $DER = $#{$REF2};
			print "\t\tBranche $BR : $DER\n";
		}
	} else { # comparaison client/serveur
		my ($cbranche, $cver) = @$client; my $sver = $#{$EV{$ent}{$cbranche}};
		print "\t$ent : ";
		if ($cver == $sver) { print "$cbranche:$cver (sync)\n"; }
		else { print "[client: $cbranche:$cver] [serveur: $cbranche:$sver]\n"; }
	}
}
