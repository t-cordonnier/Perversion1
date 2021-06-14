use Getopt::Long;


my ($FORMAT, $STABLE, $REF, $UNIT);
GetOptions (
	'format|f:s' => \$FORMAT,
	'stable|s' => \$STABLE, 
	'ref|R:s' => \$REF,
	'unit|U:s' => \$UNIT
); $UNIT ||= 'global';

unless (@ARGV) {
	require PV::Local; %MESSAGES = PV::Local::messages ('add') unless %MESSAGES;
	die "$MESSAGES{param_manque}\n$MESSAGES{syntaxe}";
}

use PV::Conf; my ($PWD, $prefix) = PV::Conf::basedir();
do "$PWD/.pver/conf.pl";

my @REFS; if ($OPT{r}) { @REFS = ($OPT{r}); }
else {
	opendir (DIRREFS, "$PWD/.pver");
	@REFS = grep { ($_ !~ /^\./) && (-d "$PWD/.pver/$_") } readdir(DIRREFS);
	close (DIRREFS);
}

my @NENTREES = ();
while (my $fic = shift (@ARGV)) {
	if (! -e $fic) {
		require PV::Local; %MESSAGES = PV::Local::messages ('add') unless %MESSAGES;
		print "$MESSAGES{fic_non_exist} : $fic.\n";
		next;
	}
	$fic = "$prefix/$fic" if $prefix; 
	$fic =~ s|/\./|/|g; $fic =~ s|(\.+)/\.\.||g; $fic =~ s|^/+||g; $fic =~ s|/$||; 
	next unless $fic && $fic !~ m|/\.[^/]+$|;
	my $fmt = 'std';
	if ($$STABLE) { $fmt = 'stable'; }
	elsif (-d $fic) { $fmt = 'dir'; }
	elsif ($FORMAT) { $fmt = $FORMAT; }
	elsif (-T $fic) { $fmt = 'txt'; }
	elsif (-B $fic) { $fmt = 'bin'; }
	elsif (-l $fic) { $fmt = 'lnk'; }
	push (@NENTREES, ['+', $fmt, $fic]); print "add -U $UNIT $fmt $fic\n";
}


while (my $ref = shift (@REFS)) { # ajouter dans tous les référentiels
	print "--- $ref ---\n"; $CONF{ref}{$ref}{unit}{$UNIT} ||= [ ($CONF{ref}{$ref}{branche} || 'base'), 0 ];
	use PV::Entrees; my %ENTREES = PV::Entrees::lire ('.', $ref); 
	my %EENT = map { (${$_}[-1] => $_) } (@{$ENTREES{$UNIT}});
	foreach my $E (@NENTREES) {
		my $nom = ${$E}[-1]; my $dir = dirname($nom); # dernier nom connu
		$EENT{$nom} ||= $E; 
		while ($dir !~ /^\./) {
			$EENT{$dir} ||= [ '+', 'dir', $dir ];
			$dir = dirname ($dir);
		}
	}
	$ENTREES{$UNIT} = [ sort { ${$a}[-1] cmp ${$b}[-1] } values(%EENT) ];

	PV::Entrees::ecrire ('.', $ref, $CONF{annul}, %ENTREES);
}

PV::Conf::ecrire (%CONF, "$PWD/.pver/conf.pl", 'CONF');
# chdir $PWD;

