use PV::Conf;
use PV::Archive;
use PV::Serv;
use PV::Local;

use Getopt::Long;
use File::Copy;



my ($REF, $UNIT, $DATE, $ARCH, $PROJET, $TAG, $BRANCHE, $LOGIN, $EXPORT, $TRACE, $VERSION);
GetOptions (
	'ref|R=s' => \$REF, 'archive|a=s' => \$ARCH,
	'date|D:s' => \$DATE, 'tag|T:s' => \$TAG,  'version|v:s' => \$VERSION,	
	'projet|p=s' => \$PROJET,  'unit|U:s' => \$UNIT,  'branche|b:s' => \$BRANCHE, 
	'login|L:s' => \$LOGIN,  'export|x' => \$EXPORT, 
	'verb|v:i' => \$TRACE, 
);
my @UNIT = split(/,/, $UNIT); print "Unté: $UNIT\n" if $UNIT;
$REF ||= 'Ref0'; $BRANCHE ||= 'base';
$ARCH ||= shift; $PROJET ||= shift; die 'pver get : indiquer au moins l\'archive et le projet' unless $ARCH && $PROJET;
if ($DATE =~ m|(\d+)/(\d+)/(\d+)|) {
	require Time::Local;
	my ($Y, $M, $D) = ($1, $2, $3); my ($h, $m, $s) = (0, 0, 0);
	($h, $m, $s) = ($1, $2, substr($3,1)) if $DATE =~ m|(\d+):(\d+)(:\d+)?|;
	$DATE =  Time::Local::timelocal ($s, $m, $h, $D, $M - 1, $Y);
}

my $aref = create PV::Archive (archive => $ARCH, projet => $PROJET, branche => $BRANCHE, login => $LOGIN);
$aref->connect or die $@; mkdir '.pver'; my %EV; my %GET;

%CONF = (
	trace => $TRACE, 
	defaultref => $REF, ref => { $REF => {
		archive => $ARCH, projet => $PROJET, login => $LOGIN,
	}}
);
if ($aref->exist ('sconf.pl')) {
	$aref->get ('sconf.pl', '.pver/sconf.pl');
	do '.pver/sconf.pl'; unlink '.pver/sconf.pl';
	$CONF{ref}{$REF}{serv} = \%SCONF;
}

%EV = PV::Serv::evenements ('aref' => $aref, projet => $PROJET);
if ($TAG) {
	$aref->get ("$PROJET/tags", '.pver/tags');
	open (TAGS, '.pver/tags') or die "Impossible d'ouvrir le fichier tags.";
	while (<TAGS>) {
		my ($ltag, @refs) = split (/\t/);
		next unless $TAG eq $ltag;
		while (my $ref = shift(@refs)) {
			my ($unit, $branche, $rev) = split(':', $ref);
			next if $UNIT and ! (grep { $_ eq $unit } @UNIT);
			$GET{$unit} = [$branche, $rev];
		}
		last;
	}
	unlink '.pver/tags';
} else {
	while (my ($unit, $ref1) = each (%EV)) {
		my ($unit0) = grep { /^$unit:?/ } @UNIT; next if @UNIT and ! $unit0;
		my $branche0 = $BRANCHE; $branche0 = $1 if $unit0 =~ /^\w+:(\w+)/;
		my @rev = @{$$ref1{$branche0}}; 
		if ($DATE) {
			my $min = 0;
			REV: for (my $i = 1; $i <= $#rev; $i++) {
				if ($rev[$i] <= $DATE) { $min = $i; } else { last REV; }
			}
			$GET{$unit} = [$branche0, $min] unless $min == 0;
		} elsif ($VERSION) {
			$GET{$unit} = [$branche0, $VERSION];
		} elsif ($unit0 =~ /:(\d+)$/) {
			$GET{$unit} = [$branche0, $1];
		} else {
			$GET{$unit} = [$branche0, $#rev] if @rev;
		}
	}
}

my $ext = $SCONF{format}; $ext = '.' . $ext if $ext;
use PV::Entrees; my %ENTREES = PV::Entrees::lire ('.', $REF); 
my %subst = (PROJET => $PROJET, TAG => $TAG); 
mkdir ".pver/$REF"; mkdir ".pver/$REF/clone";
while (my ($unit, $ver) = each (%GET)) {
	next if $UNIT and ! (grep { /^$unit:?/ } @UNIT);
	next unless $$ver[1]; # ne pas sortir les entités vides
	print "GET $unit : ", $$ver[0], '/', $$ver[1], "\n"; $subst{UNITE} = $unit; $subst{BRANCHE} = $$ver[0];  my $enFic, $sorFic;
	# Cherche et extrait le dernier cache en date
	my $revbase = $$ver[1]; until ($aref->exist($enFic = "$PROJET/$unit/$$ver[0]/${revbase}-cache$ext")) { $revbase--; die "Extraction impossible de $unit : pas de cache\n" if $revbase < 0;}
	print "\tARCH cache : $enFic\n"; $aref->get ($enFic, $sorFic = ".pver/$unit-${revbase}-cache$ext");
	if ($ext =~ /zip/) { system 'unzip', $sorFic; }
	elsif ($ext =~ /tar/) { system 'tar', 'xf',  $sorFic; }
	elsif ($ext =~ /tgz/) { system 'tar', 'xfz', $sorFic; }
	unlink $sorFic;
	
	# reconstitue le fichier des entrées
	if (open (EEN, 'pver-en')) {
		my @EUNIT = ();  
		while (my $ligne = <EEN>) {
			chop ($ligne); my ($ev, $fmt, @noms) = split(/\t/, $ligne); 
			next if $ev eq '-'; # fichiers supprimé
			my $fic = $noms[-1] or next;
			push (@EUNIT, [ '.', $fmt, $fic ]);
			if (-d $noms[-1]) { $? = 0; mkdir ".pver/$REF/clone/$fic"; }
			else {
				my $dir = dirname($fic); system 'mkdir', '--parents', ".pver/$REF/clone/$dir";
				system 'cp', $fic, ".pver/$REF/clone/$fic";
			}
			print SEN $unit, "\t", $_ unless $?;
		}
		close (EEN); unlink 'pver-en'; $ENTREES{$unit} = \@EUNIT; 
	}
	PV::Entrees::ecrire ('.', $REF, $CONF{annul}, %ENTREES);

	# si le cache n'est pas le dernier, appliquer les correctifs successifs
	$enFic = ""; # Pour pouvoir vérifier si on est rentré dans la boucle
	while ($revbase < $$ver[1]) {
		$revbase++; $enFic = "$PROJET/$unit/$$ver[0]/${revbase}$ext";
		print "\tARCH diff : $enFic\n";
		$aref->get ($enFic, $sorFic = ".pver/$unit-${revbase}$ext");
		{
			local @ARGV = ('--patch' => $sorFic, '--ref' => $REF, '--unit' => $unit, '--ver' => $revbase, '--clone');
			do 'apply.pl'; die $@ if $@;
		}
		unlink $sorFic; 
		%ENTREES = PV::Entrees::lire ('.', $REF); # pour prendre en compte les modifications 
	
		# Effectuer les transformations pour le cas où elles seraient présentes dans des lignes de contexte du patch
		$subst{REV} = $revbase;  $subst{DATE} = $EV{$unit}{$$ver[0]}[$revbase];
		foreach my $E0 (@{$ENTREES{$unit}}) {
			foreach my $fic ($$E0[-1], ".pver/$REF/clone/$$E0[-1]") {
				PV::Local::substitutions ($fic, %subst) if -T $fic;
			}
		}
	}

	# Effectuer les transformations pour le cas où on ne serait jamais rentré dans la boucle while
	unless ($enFic) {
		$subst{REV} = $revbase;  $subst{DATE} = $EV{$unit}{$$ver[0]}[$revbase];
		foreach my $E0 (@{$ENTREES{$unit}}) {
			foreach my $fic ($$E0[-1], ".pver/$REF/clone/$$E0[-1]") {
				PV::Local::substitutions ($fic, %subst) if -T $fic;
			}
		}
	}
}

unless ($EXPORT) {
	$CONF{ref}{$REF}{unit} = \%GET;
# 	PV::Entrees::ecrire ('.', $REF, $CONF{annul}, %ENTREES); 
	PV::Conf::ecrire (%CONF, '.pver/conf.pl', 'CONF');
	unlink ".pver/$REF/clone/pver-en";
} else {
	system qw(rm -Rf .pver); # version d'exportation : pour diffusion donc sans .pver
}

