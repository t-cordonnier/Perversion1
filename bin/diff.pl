use Getopt::Std;

my %OPT;
getopts ('vFU:R:', \%OPT);
$OPT{U} ||= 'global';

my $PWD = $ENV{PWD}, $prefix = '';
while (! -e ".pver") {
	die "Impossible de trouver le répertoire racine" if $ENV{PWD} eq '/';
	my $idx = rindex($PWD,'/'); my $ap = substr($PWD, $idx + 1);
	$prefix = "$ap/$prefix"; chdir '..'; $PWD = substr($PWD,0, $idx);
}
$prefix ||= '.';

my $REF = $OPT{R}; unless ($REF) { do "$PWD/.pver/conf.pl"; $REF = $CONF{defaultref}; }

my $brief = '-u'; $brief = "--brief" unless $OPT{v};
if (my $FIC = shift) {
	$prefix .= "/$FIC"; $brief = '' unless -d $FIC;
}
open (DIFF, "diff -r $brief .pver/$REF/clone/$prefix $prefix |") or die "Erreur diff\n";
while (<DIFF>) {
	s|\.pver/$REF/clone/\.|{REFERENCE}|;
	s|\./|{TRAVAIL}/|;
	if ($OPT{F}) {
		if (m|\{REFERENCE\}/(.+):\s(.+)\n?$|) {
			$cmd = "pver del $1/$2\n"; $cmd =~ s|/+|/|g; print $cmd; next;
		} elsif (m|\{TRAVAIL\}/(.+):\s(.+)\n?$|) {
			my $nouv = "$1/$2"; $cmd = "pver add -U $OPT{U} $nouv\n"; $cmd =~ s|/+|/|g;
			print $cmd; add_recursif ($nouv) if -d $nouv;
			next;
		} else {
			next;
		}
	}
	print;
}
close (DIFF);

chdir $PWD;

sub add_recursif {
	my ($dir) = @_;
	local *DIR; opendir (DIR, $dir);
	while (my $fic = readdir(DIR)) {
		next if $fic =~ /^\./;
		$cmd = "pver add -U $OPT{U} $dir/$fic\n"; $cmd =~ s|/+|/|g; print $cmd;
		add_recursif ("$dir/$fic") if -d "$PWD/$dir/$fic";
	} closedir (DIR);
}
