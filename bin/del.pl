use Getopt::Std;
use Getopt::Long;

my %OPT;
getopts ('R:U:', \%OPT);
GetOptions ('ref' => \$OPT{R}) unless $OPT{R};
GetOptions ('unit' => \$OPT{U}) unless $OPT{U};

unless (@ARGV) {
	local $/ = undef; die <DATA>;
}

my $PWD = $ENV{PWD}, $prefix = '';
while (! -e "$PWD/.pver") {
	die "Impossible de trouver le répertoire racine" if $ENV{PWD} eq '/';
	my $idx = rindex($PWD,'/'); my $ap = substr($PWD, $idx + 1);
	$prefix = "$ap/$prefix"; chdir '..'; $PWD = substr($PWD,0, $idx);
}
$prefix =~ s|/$||g; @ARGV = map { "$prefix/$_" } @ARGV if $prefix;
do "$PWD/.pver/conf.pl"; 

my @REFS; if ($OPT{r}) { @REFS = ($OPT{r}); }
else {
	opendir (DIRREFS, "$PWD/.pver");
	@REFS = grep {($_ !~ /^\./) && (-d "$PWD/.pver/$_") } readdir(DIRREFS);
	close (DIRREFS);
}

while (my $ref = shift (@REFS)) {
	print "--- $ref ---\n";
	use PV::Entrees; my %ENTREES = PV::Entrees::lire ('.', $ref); 
	my @UNITES = keys(%ENTREES); @UNITES = ($OPT{U}) if $OPT{U}; 
	foreach my $unite (@UNITES) {
		my $REF_TABLE = $ENTREES{$unite}; 
		LOOP_ENT: foreach my $entree (@$REF_TABLE) {
			foreach my $fic (@ARGV) {
				if (${$entree}[-1] eq $fic) { ${$entree}[0] = '-'; next LOOP_ENT; }
				elsif (${$entree}[-1] =~ m|^$fic/|) { ${$entree}[0] = '-'; next LOOP_ENT; }
			}
		}
	}
	
	PV::Entrees::ecrire ('.', $ref, $CONF{annul}, %ENTREES);
}

# chdir $PWD;


__DATA__

pver del : paramètres manquants
Syntaxe :
	pver del [-R référentiel] [-U unité] fichiers

Supprime les fichiers de la copie locale : ils ne passeront plus au prochain commit
