use Getopt::Long;
use File::Basename;

my ($REF, $SYS, $CREP);
GetOptions ( 'ref|R:s' => \$REF,  'sys|s' => \$SYS, 'cree-rep' => \$CREP, 'c' => \$CREP);

use PV::Local; my %MESSAGES = PV::Local::messages('move');

unless (@ARGV >= 2) {
	die "$MESSAGES{non_param}\n$MESSAGES{aide}";
}

use PV::Conf; my ($PWD, $prefix) = PV::Conf::basedir(); do "$PWD/.pver/conf.pl";

if ($SYS) {
	local $ENV{PWD}; chdir $PWD;
	system "mv", @ARGV;
}

my @REFS = (); if ($OPT{R}) { @REFS = ($OPT{R}); }
else { local *DIR; opendir (DIR, "$PWD/.pver"); @REFS = grep { (-d "$PWD/.pver/$_") && ($_ !~ /^\./) } readdir(DIR); closedir (DIR); }

foreach my $REF (@REFS) {
	my @PARAMS = @ARGV; @PARAMS = map { "$prefix/$_" } @PARAMS if $prefix; 
	my $dest = pop (@PARAMS); # dernier paramètre, en partant de la droite
	use PV::Entrees; my %ENTREES = PV::Entrees::lire ($PWD, $REF);
	my %exist = PV::Entrees::trouve ($dest, -1, %ENTREES);
	my %origParams = map { $_ => {PV::Entrees::trouve ($_, -1, %ENTREES)} } @PARAMS;
	
	while (my ($UNIT, $TABLE) = each (%ENTREES)) {
	
		my $modif = 0; 
		if (-d $dest) {
			if ((scalar(@PARAMS) == 1) && (!$exist{$UNIT})) {
				# renommer un répertoire
				print STDERR "$MESSAGES{renomme_rep} $PARAMS[0] --> $dest\n" if $CONF{trace}; 
				foreach my $entree (@$TABLE) {
					next if ${$entree}[0] eq '-'; 
					if (${$entree}[-1] eq $PARAMS[0]) {
						${$entree}[0] = '>' if ${$entree}[0] eq '.'; $modif++; 
						push (@$entree, $dest); # nouveau nom de répertoire
						print STDERR "\t$$entree[-2] --> $$entree[-1]\n" if $CONF{trace} > 2;
					} elsif (${$entree}[-1] =~ m|^$PARAMS[0]/|) {
						${$entree}[0] = '>' if ${$entree}[0] eq '.'; $modif++; 
						my $copie = ${$entree}[-1]; $copie =~ s|^$PARAMS[0]/|$dest/|;
						push (@$entree, $copie); # nouveau nom de fichier
						print STDERR "\t$$entree[-2] --> $$entree[-1]\n" if $CONF{trace} > 2;
					}
				} 
			}  else {
				# copier tout dans le répertoire nouvellement créé
				die $MESSAGES{rep_non_exist} unless $exist;
				foreach my $fic (@PARAMS) { # on part de la gauche
					my $base = basename($fic); my $fic1 = $fic; $fic1 =~ s|^\./||;
					foreach my $entree (@$TABLE) {
						next if ${$entree}[0] eq '-'; 
						if (${$entree}[-1] eq $fic1) {
							${$entree}[0] = '>' if ${$entree}[0] eq '.'; $modif++; 
							push (@$entree, "$dest/$base"); # nouveau nom
							print STDERR "\t$$entree[-2] --> $$entree[-1]\n" if $CONF{trace} > 2;
						} elsif (${$entree}[-1] =~ m|^$fic1/|) {
							my $COPIE = ${$entree}[-1]; $COPIE =~ s|^$fic1/|$dest/|;
							push (@$entree, $COPIE);
							$modif++; 
							print STDERR "\t$$entree[-2] --> $$entree[-1]\n" if $CONF{trace} > 2;
						}
					} 
				}
			}
		} elsif (-e $dest) { # il doit au moins exister
			die  "$MESSAGES{fic_existe} $dest" if $exist{$UNIT};
			my $fic = $PARAMS[0]; $fic =~ s|^\.?/||; # on d�lace un seul fichier
			foreach my $entree (@$TABLE) {
				next if ${$entree}[0] eq '-'; 
				if ($fic eq ${$entree}[-1]) {
					${$entree}[0] = '>' if ${$entree}[0] eq '.'; push (@$entree, $dest);
					$modif++; 
					print STDERR "\t$$entree[-2] --> $$entree[-1]\n" if $CONF{trace} > 2;
				}
			} 
		} else {
			die $MESSAGES{non_existe};
		}

		if ($modif) {
			my @COPIE = @$TABLE; 
			foreach my $E0 (@$TABLE) {
				my $dir = dirname (${$E0}[-1]); next if $dir eq '.'; 
				unless (grep { ${$_}[-1] eq $dir } @COPIE) {
					if ($CREP) { push (@COPIE, ['+', 'dir', $dir]); }
					else { die $MESSAGES{non_existe_parent}; }
				} 
			}
			@$TABLE = sort { ${$a}[-1] cmp ${$b}[-1] } @COPIE; 
		}
	}
	PV::Entrees::ecrire ($PWD, $REF, $CONF{annul}, %ENTREES); 
}

# chdir $PWD;

