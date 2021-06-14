#! /usr/bin/perl

my $DIR = $ENV{PWD};
while (! -e "$DIR/.pver") {
	my $idx = rindex ($DIR, '/');
	if ($idx < 1) {
		die "Impossible de retrouver le répertoire de base";
	}
	$DIR = substr($DIR, 0, $idx);
}

do "$DIR/.pver/conf.pl";

use Getopt::Long; Getopt::Long::GetOptions (
	'message|M:s' => \$OPT_MSG,  'ligne|L:s' => \$OPT_LIGNE, 
	'date|D:s' => \$OPT_DATE, 'auteur|A:s' => \$OPT_AUTEUR, 
	'ref|R:s' => \$OPT_REF, 
	'voir-ev|ev' => \$OPT_VOIR_EV, 
	'voir-modifs|m' => \$OPT_VOIR_MODIFS, 
);

my $REF = $OPT_REF || $CONF{defaultref}; my $REFCFG = $CONF{ref}{$REF};
$OPT_AUTEUR ||= $$REFCFG{id} || "<$ENV{LOGNAME}\@$ENV{HOSTNAME}>";
$$REFCFG{revision} += 1;
$OPT_DATE ||= '#DATE#';
$OPT_VOIR_EV = 1 if $$REFCFG{'voir-ev'}; $OPT_MSG = 1 if $$REFCFG{'voir-modifs'};

our $EVENEMENTS = "";
if ($OPT_VOIR_EV && open (EV, "$DIR/.pver/$REF/ev")) {
	require PV::Entrees; my %ENTREES = PV::Entrees::lire ($DIR, $REF);
	while (my ($unite, $table) = each(%ENTREES)) {
		my @ADD, @DEL, @MOV, @CPY; 
		foreach my $entree (@$table) {
			if ($$entree[0] eq '+') { push (@ADD, $entree); }
			elsif ($$entree[0] eq '-') { push (@DEL, $entree); }
			elsif ($$entree[0] eq '>') { push (@MOV, $entree); }
			elsif ($$entree[0] eq '=') { push (@CPY, $entree); }
		}
		if (@ADD) { $EVENEMENTS .= "[AJOUTS $unite]\t" . join(" ", map { $$_[-1] } @ADD) . "\n"; }
		if (@DEL) { $EVENEMENTS .= "[SUPPRESSIONS $unite]\t" . join(" ", map { $$_[-1] } @DEL) . "\n"; }
		if (@MOV) { $EVENEMENTS .= "[DEPLACEMENTS $unite]\t" . join("\t", map { "$$_[2] -> $$_[-1]" } @MOV) . "\n"; }
		if (@CPY) { $EVENEMENTS .= "[COPIES $unite]\t" . join("\t", map { "$$_[2] -> $$_[-1]" } @CPY) . "\n"; }
	}	
}
if ($OPT_VOIR_MODIFS) {
	$EVENEMENTS .= "[MODIFICATIONS]	";
	open (DIFF, "diff -r --brief $DIR .pver/$REF/clone");
	while (<DIFF>) { chop; $EVENEMENTS .= $_; }
	close (DIFF); $EVENEMENTS .= "\n";
}
$EVENEMENTS = "\n$EVENEMENTS\n";

my $VERSIONS = ""; my $LIGNES = "";
while (my ($k, $v) = each (%{$CONF{ref}{$REF}{unit}})) {
	$VERSIONS .= "[VERSION $k]	$$v[0]:" . ($$v[1] + 1) . "\n";
	$LIGNES .= "[LIGNE $k]\t$OPT_LIGNE\n";
}


open (LOG, "> $DIR/.pver/$REF/log");
print LOG << "EOF";
[AUTEUR]	$OPT_AUTEUR
[DATE]		$OPT_DATE
$VERSIONS
$EVENEMENTS
$LIGNES

$OPT_MSG
EOF
close (LOG);

print "$DIR/.pver/$REF/log\n";

