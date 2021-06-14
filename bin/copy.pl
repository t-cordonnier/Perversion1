use Getopt::Long;
use File::Basename;

my ($REF, $SYS);
GetOptions ( 'ref|R:s' => \$REF,  'sys|s' => \$SYS );

unless (@ARGV >= 2) {
	require PV::Local; my %MESSAGES = PV::Local::messages('copy');
	die "$MESSAGES{non_param}\n$MESSAGES{aide}";
}

use PV::Conf; my ($PWD, $prefix) = PV::Conf::basedir(); $prefix ||= '.'; do "$PWD/.pver/conf.pl";

if ($SYS) {
	local $ENV{PWD}; chdir $PWD;
	system 'cp', '-R', @ARGV;
}

my @REFS = (); if ($OPT{R}) { @REFS = ($OPT{R}); }
else { local *DIR; opendir (DIR, "$PWD/.pver"); @REFS = grep { (-d "$PWD/.pver/$_") && ($_ !~ /^\./) } readdir(DIR); closedir (DIR); }

foreach my $REF (@REFS) {
	my @PARAMS = map { "$prefix/$_" } @ARGV;
	my $dest = pop (@PARAMS); $dest =~ s|^\./||;  # dernier paramètre, en partant de la droite
	use PV::Entrees; my %ENTREES = PV::Entrees::lire ($PWD, $REF); my %ENTREES2 = %ENTREES; 

	while (my ($UNIT, $TABLE) = each(%ENTREES)) {
	
		my $modif = 0; 
		my $exist = grep { ${$_}[-1] eq $dest } @$TABLE;
		my @COPIE = @$TABLE; 
		if (-d $dest) {
			if ((scalar(@PARAMS) == 1) && (-d $PARAMS[0]) && (!$exist)) {
				# copier un répertoire intégralement
				push (@COPIE, ['=', 'dir', $PARAMS[0], $dest]) and $modif++;
				foreach my $entree (@$TABLE) {
					if (${$entree}[-1] =~ m|^$PARAMS[0]/|) {
						my $COPIE = ${$entree}[-1]; $COPIE =~ s|^$PARAMS[0]/|$dest/|;
						push (@COPIE, [ '=', ${$entree}[1], ${$entree}[2], $COPIE ]);
						$modif++; 
					}
				} 
			} else {
				# copier tout dans le répertoire nouvellement créé
				push (@COPIE, ['=', 'dir', $PARAMS[0], $dest]) and $modif++ unless $exist;
				foreach my $fic (@PARAMS) { # on part de la gauche
					my $base = basename($fic); my $fic1 = $fic; $fic1 =~ s|^\./||;
					foreach my $entree (@$TABLE) {
						if ((${$entree}[-1] eq $fic1) || (${$entree}[-1] =~ m|^$fic1/|)) {
							my $FCOPIE = ${$entree}[-1]; $FCOPIE =~ s|^$fic1/|$dest/|;
							push (@COPIE, [ '=', ${$entree}[1], ${$entree}[2], $FCOPIE]);
							$modif++; 
						}
					} 
				}
			}
		} elsif (-e $dest) { # il doit au moins exister
			if ($exist) {
				require PV::Local; my %MESSAGES = PV::Local::messages('copy');
				die "$MESSAGES{fic_existe} $dest";
			}
			my $fic = $PARAMS[0]; $fic =~ s|^\.?/||; # on déplace un seul fichier
			foreach my $entree (@$TABLE) {
				if ($fic eq ${$entree}[-1]) {
					push (@COPIE, [ '=', ${$entree}[1], ${$entree}[2], $dest ]);
					$modif++; 
				}
			} 
		} else {
			require PV::Local; my %MESSAGES = PV::Local::messages('copy');
			die $MESSAGES{non_existe};
		}

		$ENTREES2{$UNIT} = [ sort { ${$a}[-1] cmp ${$b}[-1] } @COPIE ] if $modif;
	}
	PV::Entrees::ecrire ($PWD, $REF, $CONF{annul}, %ENTREES2); 
}

