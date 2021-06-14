
eval {
	local @ARGV = (grep { $_ !~ /^\-\-?[ac]/ } @ARGV, '--sortie' => '(commit)');
	print STDERR 'pver crpatch ', join(' ', @ARGV), "\n";
	do "crpatch.pl";
};
if ($@) {
	die $@;
}

use PV::Archive;
use Getopt::Long;
use PV::Conf;
use PV::Local; 
use File::Copy;

my ($REF, $UNIT, $CONSERVE, $ATOMIC, $NODEL);
GetOptions (
	'ref|R:s' => \$REF, 
	'unit|U:s' => \$UNIT, 'date|D:s' => \$DATE, 
	'conserve|c' => \$CONSERVE, 'atom|a' => \$ATOMIC, 'nodel' => \$NODEL
);
my ($DIR) = &PV::Conf::basedir(); do "$DIR/.pver/conf.pl";
$REF ||= $CONF{defaultref}; my $REFCFG = $CONF{ref}{$REF}; my $REFDIR = "$DIR/.pver/$REF";
$ATOMIC ||= $CONF{ref}{$REF}{serv}{atom} || $CONF{atom};
my ($DATESTR); ($DATE, $DATESTR) = &PV::Local::analyse_date($DATE); 

my %MESSAGES = PV::Local::messages ('commit');

unless (-e "$REFDIR/log") {
	die $MESSAGES{manque_log};
}
my $arch = create PV::Archive (%$REFCFG); $arch->connect() or die "Impossible de se connecter au référentiel $REF\n";



my @UNITES = keys (%{$$REFCFG{unit}});
my @UNIT = @UNITES; if ($UNIT) { @UNIT = split (/,/, $UNIT); }

use PV::Entrees; our %ENTREES = PV::Entrees::lire ($DIR, $REF);


my ($UNITCFG, $UNITDIR); my $EVSTR = ''; my @OK;

# --------- test de faisabilité de la validation -------------
print STDERR "$MESSAGES{verif_unites}\n" if $CONF{trace} > 0;
while ($UNIT = shift (@UNIT)) {
	print STDERR "\t$MESSAGES{unite} $UNIT...\n" if $CONF{trace} > 1;
	$UNITCFG = $$REFCFG{unit}{$UNIT}; my ($branche, $rev) = @{$UNITCFG}; $rev++;
	$UNITDIR = "$REFDIR/$UNIT-$rev";

	if (open (ERR, "$UNITDIR/err")) { # un fichier manque... l'entité sera validée au prochain appel
		print "\t$UNIT : $MESSAGES{err_fichiers} : ";
		print join (',', <ERR>); close (ERR); print "\n";
		if ($ATOMIC) { die; } else { next; }
	}
	my @EV = grep { ${$_}[0] ne '.' } @{$ENTREES{$UNIT}};
	unless ( (@EV) or ($rev <= 1) or (-e "$UNITDIR/diff") or (-e "$UNITDIR/add") or (-e "$UNITDIR/txt_rdiff") ) {
		print "\t$UNIT : $MESSAGES{aucun_changement}\n"; next;
	} else {
		print "\t$UNIT : $MESSAGES{revision} $branche:$rev\n";
	}

	# ---- test sur le serveur ----
	my $F_Ext = '.' . $$REFCFG{serv}{format}; $F_Ext = '' if $F_Ext eq '.';
	if ($arch->exist ("$$REFCFG{projet}/$UNIT/$branche/$rev$F_Ext")) {
		print "$MESSAGES{revision} $UNIT/$branche/$rev $MESSAGES{non_sync}\n";
		if ($ATOMIC) { die; } else { next; }
	}
	next unless -e "$UNITDIR/$rev-cache$F_Ext"; push (@OK, $UNIT);
	print STDERR "\t$MESSAGES{unite} $UNIT ok" if $CONF{trace} > 1;
}


# --------- envoi effectif sur le serveur ------------
print STDERR "$MESSAGES{envoi_serveur}\n" if $CONF{trace} > 0;
foreach my $UNIT (@OK) {
	$UNITCFG = $$REFCFG{unit}{$UNIT}; my ($branche, $rev) = @{$UNITCFG}; $rev++;
	$UNITDIR = "$REFDIR/$UNIT-$rev";

	# ---- formats demandés (la création des fichiers a été faite dans crpatch) ----
	print STDERR "\t$MESSAGES{envoi_serveur_de} $UNIT : " if $CONF{trace} > 1;
	my ($F_Cache, $F_Diff, $F_Ext);
	my $FMT = $$REFCFG{serv}{format}; $FMT =~ s/\s//; print "\tFORMAT = '$FMT'\n" if $CONF{trace} > 3;
	if ($FMT eq 'tar') {
		$F_Cache = "$UNITDIR/$rev-cache.tar"; $F_Diff = "$UNITDIR/$rev.tar"; $F_Ext = '.tar';
	} elsif ($FMT eq 'zip') {
		$F_Cache = "$UNITDIR/$rev-cache.zip"; $F_Diff = "$UNITDIR/$rev.zip";  $F_Ext = '.zip';
	} elsif ($FMT eq 'tgz') {
		$F_Cache = "$UNITDIR/$rev-cache.tgz"; $F_Diff = "$UNITDIR/$rev.tgz";  $F_Ext = '.tgz';
	} else {
		$F_Cache = "$UNITDIR/cache";
		$F_Diff = "$UNITDIR/en $UNITDIR/log $UNITDIR/add $UNITDIR/diff $UNITDIR/txt_rdiff";
		$F_Ext = '';
	}

	my $DEST_BRANCHE = "$$REFCFG{projet}/$UNIT/$branche";
	my $DEST_DIFF = "$DEST_BRANCHE/$rev" . $F_Ext, $DEST_CACHE =  "$DEST_BRANCHE/$rev-cache" . $F_Ext;
	print STDERR "\t\tarch->put ($F_Cache,$DEST_CACHE)\n" if $CONF{trace} > 2;
	$arch->put ($F_Cache, $DEST_CACHE); $EVSTR .= "$DATE\t$UNIT\t$branche\t$rev\n";
	{
		local $/ = undef; print "\tEnregistrement du journal...\n" if $CONF{trace} > 3;
		open (LOG, "$UNITDIR/log"); my $txt = <LOG>; close (LOG);
		$arch->ajoute ("$DEST_BRANCHE/log", $txt . "\n\n----------\n\n");
	}
	if ($$UNITCFG[1]) { # pas le premier commit : créer l'archive de différences
		print STDERR "\t\tarch->put ($F_Diff,$DEST_DIFF)\n" if $CONF{trace} > 2;
		if ($F_Ext) {
			$arch->put ($F_Diff, $DEST_DIFF); # $arch->put ($F_Cache, $DEST_CACHE);
		} else {
			$arch->makedir ($DEST_DIFF);
			foreach ('en', 'log', 'add', 'diff', 'txt_rdiff') {
				$arch->put ("$UNITDIR/$_", "$DEST_DIFF/$_") if "$UNITDIR/$_";
			}
			# $arch->put ($F_Cache, $DEST_CACHE);
		}
		my $DO_DELETE = ($$UNITCFG[1] > 1); $DO_DELETE = 0 if $CONSERVE; 
		$DO_DELETE = 0 if $arch->liens("$DEST_BRANCHE/$$UNITCFG[1]-cache$F_Ext") > 1;
		if (defined $$REFCFG{serv}{conserve}) {
			if ($$REFCFG{serv}{conserve} =~ /^\d+$/) { # conserve une version sur xxx
				$DO_DELETE = $DO_DELETE && (($$UNITCFG[1] % $$REFCFG{serv}{conserve}) != 0);
			}
		}
		print "\tSuppression $DEST_BRANCHE/$$UNITCFG[1]-cache$F_Ext\n" if $DO_DELETE and ($CONF{trace} > 3);
		$arch->supprime ("$DEST_BRANCHE/$$UNITCFG[1]-cache" . $F_Ext) if $DO_DELETE;
	}
	$$UNITCFG[1] = $rev;
	@LOG = grep { !(/^\[\w+\s+$UNIT\]/ or /^<$UNIT>/)  } @LOG;
	system 'rm', '-Rf', $UNITDIR unless $NODEL; delete $EV{$UNIT}; 
}

# --- validation définitive : on modifie la configuration
$arch->ajoute ("$$REFCFG{projet}/ev", $EVSTR); $arch->disconnect;

# ------------ reconstitution du fichier clone final ------------
print STDERR "$MESSAGES{cons_clone}\n" if $CONF{trace} > 0;
mkdir "$REFDIR/clone.new"; 
my %subst = (PROJET => $$REFCFG{projet}, DATE => $DATESTR); 
foreach my $UNITE (@UNITES) {
	my $TABLE = $ENTREES{$UNITE};  
	my $VALIDE =  grep { $_ eq $UNITE } @OK;
	$subst{UNITE} = $UNITE; @subst{'BRANCHE','REV'} = @{$$REFCFG{unit}{$UNITE}};
	if ($VALIDE) { # unitï¿œvalidï¿œ sur le serveur : on prend le contenu de la copie locale
		$TABLE = $ENTREES{$UNITE} = [
			sort { ${$a}[-1] cmp ${$b}[-1] } # trier par nom de fichier 
			map { [ '.', ${$_}[1], ${$_}[-1] ] } # ('.', $format, $dernier_nom)
				grep { ${$_}[0] ne '-' } @$TABLE
		];
		foreach my $ENTREE (@$TABLE) {
			if (-d $$ENTREE[-1]) { mkdir "$REFDIR/clone.new/$$ENTREE[-1]"; }
			else { 
				PV::Local::substitutions ($$ENTREE[-1], %subst); # avant la copie, pour que le clone soit substitué aussi
				File::Copy::copy ($$ENTREE[-1], "$REFDIR/clone.new/$$ENTREE[-1]"); 
			}
		}
	} else { # unité non validée sur le serveur : reprise de l'ancien cache
		foreach my $ENTREE (@$TABLE) {
			if (-d "$REFDIR/clone/$$ENTREE[2]") { mkdir "$REFDIR/clone.new/$$ENTREE[2]"; }
			else { File::Copy::copy ("$REFDIR/clone/$$ENTREE[2]", "$REFDIR/clone.new/$$ENTREE[2]"); }
		}
	}
}

if (@LOG) { open (ESLOG, "> $REFDIR/log"); print ESLOG @LOG; close (ESLOG); } else { unlink "$REFDIR/log"; }
foreach my $UNIT (@UNITES) { system "rm -Rf $REFDIR/$UNIT-$$REFCFG{unit}{$UNIT}[1]"; }
PV::Entrees::ecrire ($DIR, $REF, 0, %ENTREES); unlink "$DIR/.pver/$REF/en.$_" foreach (1 .. $CONF{annul}); 
PV::Conf::ecrire ( %CONF, "$DIR/.pver/conf.pl", 'CONF');
system "rm -Rf $REFDIR/clone; mv $REFDIR/clone.new $REFDIR/clone";
