use Getopt::Long;
use PV::Conf;
use PV::Local;
use File::Basename;



my ($REF, $UNIT, $DATE, $SORTIE, $NODEL, $TEXT);
GetOptions (
	'ref|R:s' => \$REF, 
	'unit|U:s' => \$UNIT, 
	'date|D:s' => \$DATE, 
	'sortie|S:s' => \$SORTIE, 
	'text|T' => \$TEXT, 
	'nodel' => \$NODEL,
);
our ($DIR) = PV::Conf::basedir(); do "$DIR/.pver/conf.pl";
$REF ||= $CONF{defaultref}; my $REFCFG = $CONF{ref}{$REF}; my $REFDIR = "$DIR/.pver/$REF";
my @UNITES; if ($UNIT) { @UNITES = split (/,/, $UNIT); } else { @UNITES = keys (%{$$REFCFG{unit}}); }
my ($DATESTR); ($DATE, $DATESTR) = &PV::Local::analyse_date($DATE); 
$SORTIE ||= '.'; 

my %MESSAGES = PV::Local::messages ('crpatch');

if (open (ENLOG, "$REFDIR/log")) {
	our @LOG = <ENLOG>; close (ENLOG);
} else {
	die $MESSAGES{manque_log};
}

my %TEXTDIFF = ();
if (open (RDIFF, "cd $DIR; diff -r -u $REFDIR/clone . |")) {
	my $curFic = undef;
	while (<RDIFF>) {
		if (m|^diff -r -u (\S+)|) {
			$curFic = substr($1,length("$REFDIR/clone") + 1); s|$DIR/*||g;
			$TEXTDIFF{$curFic} .= "diff -r -u $curFic\n";
		} else {
			$TEXTDIFF{$curFic} .= $_ if $curFic && ! (/^(Seulement|Only)\s/);
		}
	}
	close (RDIFF);
}

use PV::Entrees; our %ENTREES = PV::Entrees::lire ($DIR, $REF); 


print STDERR "$MESSAGES{cree_correctifs}...\n" if $CONF{trace};
while ($UNIT = shift (@UNITES)) {
	my $UNICONF = $$REFCFG{unit}{$UNIT}; my ($branche, $rev) = @$UNICONF; $rev++;
	my $UNITDIR = "$REFDIR/$UNIT-$rev"; mkdir_rec ($UNITDIR); my $TXT_RDIFF = "";
	my $UTABLE = $ENTREES{$UNIT};
	print STDERR "\t$MESSAGES{id_ref} $REF, $MESSAGES{id_unite} $UNIT, $MESSAGES{id_rev} $branche:$rev\n" 
		if $CONF{trace} > 1;
	# -- entrées --
	print STDERR "\t\t$MESSAGES{cree_cache}\n" if $CONF{trace} >= 3;
	mkdir "$UNITDIR/cache"; open (PVEREN, "> $UNITDIR/en");
	my ($DATE1, $DATESTR1) = ($DATE, $DATESTR); $DATE1 = 0 if $DATE =~ /^[AaCcMm]/;
	foreach my $ENTREE (@$UTABLE) {
		print PVEREN join("\t", @$ENTREE), "\n"; next if $$ENTREE[0] eq '-';
		my $NOM = $$ENTREE[-1]; # dernier nom de fichier connu
		if (-d $NOM) { system ('mkdir', '--parents', "$UNITDIR/cache/$NOM"); }
		else { File::Copy::copy ($NOM, "$UNITDIR/cache/$NOM"); }
		if ($DATE =~ /^[Aa]/) { my $DATE2 = time() - 86400 * -A $NOM; $DATE1 = $DATE2 if $DATE1 < $DATE2; }
		if ($DATE =~ /^[Mm]/) { my $DATE2 = time() - 86400 * -M $NOM; $DATE1 = $DATE2 if $DATE1 < $DATE2; }
		if ($DATE =~ /^[Cc]/) { my $DATE2 = time() - 86400 * -C $NOM; $DATE1 = $DATE2 if $DATE1 < $DATE2; }
	}
	close (PVEREN); system 'cp', "$UNITDIR/en", "$UNITDIR/cache/pver-en";
	# -- fichier journal --
	print STDERR "\t\t$MESSAGES{fichier_journal}...\n" if $CONF{trace} >= 3;
	if (($DATE1 =~ /^\d+$/) && ($DATE1 != $DATE)) {
		my @TIME = localtime($DATE1); $TIME[4] ++; $TIME[5] += 1900;
		$DATESTR1 = sprintf ('%04i/%02i/%02i %02i:%02i:%02i', @TIME [5,4,3,2,1,0]);
	}
	open (ESLOG, "> $UNITDIR/log"); my @LLOG = @LOG;
	foreach my $logLigne (@LLOG) {
		if ($logLigne =~ s|^\[(\w+)\s+(\w+)\](\s*)|\[$1\]$3|) { next unless $2 eq $UNIT; }
		elsif ($logLigne =~ s|^<(\w+)>\s*||) { next unless $1 eq $UNIT; }
		$logLigne =~ s|#DATE#|$DATESTR|gs;
		print ESLOG $logLigne;
	} close (ESLOG);

	if ($rev > 1) { # pas le premier commit : créer l'archive de différences
		print STDERR "\t\t$MESSAGES{rep_diff}...\n" if $CONF{trace} >= 3;
		my $dest = "$UNITDIR/diff"; mkdir_rec ($dest); 
		foreach my $ENTREE (@$UTABLE) {
			my ($ev, $fmt, @noms) = @$ENTREE; 
			print STDERR join ("\t", @$ENTREE), "\n" if $CONF{trace} >= 4; 
			if ($ev eq '-') { next; } # fichier supprimé
			elsif ($ev eq '+') { # fichier ajouté
				my $ADDDIR = "$UNITDIR/add"; mkdir_rec ($ADDDIR) unless -e $ADDDIR;
				eval { &copier_fichier ($fmt, $noms[-1], $ADDDIR, $DIR); };
				if ($@) { system "echo $fic >> $UNITDIR/err"; die $@; }
				mkdir_rec ("$dest/$noms[-1]") if $fmt eq 'dir';
			} else { # différence entre les fichiers
				my $Ancien = "$REFDIR/clone/$noms[0]", $Nouveau = "$UNITDIR/cache/$noms[-1]";
				my ($fic1, $fic2) = ($noms[0], $noms[-1]); my $Diff = ""; 
				print STDERR "diff ($fmt) $Ancien $Nouveau\n" if $CONF{trace} >= 4;

				if ($fmt eq 'dir') { mkdir_rec ("$dest/$fic2"); next; }
				elsif ($fmt eq 'txt') {
					my $taille = 0;
					if (($fic1 eq $fic2) && $TEXTDIFF{$fic1}) {
						$taille = length($TEXTDIFF{$fic1}); $Diff = \$TEXTDIFF{$fic1};
					} else {
						$Diff = "$dest/$noms[-1].diff";
						mkdir_rec (dirname($Diff)); system "diff -u $Ancien $Nouveau > $Diff";
						$taille = int (-s $Diff);
					}
					if ($taille >= ((-s $Nouveau) * 0.9)) {
						if ((-s $Nouveau > 1024) && (! $TEXT)) {
							if (ref($Diff)) { $$Diff = ''; } else { unlink $Diff; }
							$Diff = "$dest/$fic2.bsdiff"; system ('bsdiff', $Ancien, $Nouveau, $Diff);
						}
					}
					print STDERR "mkdir_rec ", dirname($Diff), "; diff -u $Ancien $Nouveau > $Diff\n" if $CONF{trace} >= 4;
				} elsif ($fmt eq 'bin') {
					$Diff = "$dest/$fic2.bsdiff";
					if (system "diff '$Ancien' '$Nouveau' > /dev/null") {
						print STDERR "bsdiff '$Ancien' '$Nouveau' '$Diff'\n" if $CONF{trace} >= 4;
						mkdir_rec (dirname($Diff)); system ('bsdiff', $Ancien, $Nouveau, $Diff);
					}
				} elsif ($fmt eq 'lnk') {
					next unless readlink("$DIR/.pver/clone/$fic1") eq readlink("$DIR/$fic2");
					if (system "ln -s $fic2 $dest/$fic2") {
						# si le système ne supporte pas les liens symboliques, les remplacer par un fichier
						open (FIC, "$dest/$fic2"); print FIC readlink($fic2); close (FIC);
					}
				}
=for later
				elsif ($fmt eq 'tar') {
					$Diff = "$dest/$fic2.bsdiff";
					system "bsdiff $Ancien $Nouveau $Diff";
				} elsif ($fmt eq 'zip') {
					$Diff = "$dest/$fic2.bsdiff";
					system "bsdiff $Ancien $Nouveau $Diff";
				}
=cut

				if (! $Diff) { print STDERR "\t??????\n" if $CONF{trace} >= 5; }
				elsif (ref ($Diff)) { $TXT_RDIFF .= $$Diff; }
				elsif (-z $Diff) { unlink $Diff; print STDERR "\t$MESSAGES{diff_vide}\n" if $CONF{trace} >= 5; }
				elsif ((-s $Diff) >= ((-s $Nouveau) * 0.9)) {
					print STDERR "\tTaille($Diff) = ", (-s $Diff), " > taille($Nouveau) = ", (-s $Nouveau), "\n" if $CONF{trace} >= 5;
					unlink $Diff; $Diff = dirname($Diff); system "cp $Nouveau $Diff";
				} else {
					print STDERR "\t$MESSAGES{diff_ok}\n" if $CONF{trace} >= 5;
				}
			}
		}
		if ($TXT_RDIFF) { open (RDIFF, "> $UNITDIR/txt_rdiff"); print RDIFF $TXT_RDIFF; close (RDIFF); }
	
		print "\t\t$MESSAGES{cree_archive}\n" if $CONF{trace} > 3;
		if (open (ERR, "$UNITDIR/err")) { # un fichier manque... l'unité sera validée au prochain appel
			print "\t$UNIT : $MESSAGES{err_fichiers} : ";
			print join (',',  <ERR>); close (ERR); print "\n";
			next;
		}
		unless ((-e "$UNITDIR/diff") || (-e "$UNITDIR/txt_rdiff") || (-e "$UNITDIR/add")) {
			print "\t$UNIT : $MESSAGES{aucun_changement}\n" if $CONF{trace} > 0;
			next;
		}
		prune ($UNITDIR);
	}

	# ---- mise au format demandé par le serveur ----
	my ($F_Cache, $F_Diff, $F_Ext, $CMD1, $CMD2);
	my $FMT = $$REFCFG{serv}{format}; $FMT =~ s/\s//; print "\tFORMAT = '$FMT'\n" if $CONF{trace} > 3;
	if ($FMT eq 'tar') {
		$F_Cache = "$UNITDIR/$rev-cache.tar"; $F_Diff = "$UNITDIR/$rev.tar"; $F_Ext = '.tar';
		$CMD1 = "cd $UNITDIR/cache; tar cf $F_Cache *";
		$CMD2 = "cd $UNITDIR ; tar cf $F_Diff en log add diff txt_rdiff" unless $rev <= 1;
	} elsif ($FMT eq 'zip') {
		$F_Cache = "$UNITDIR/$rev-cache.zip"; $F_Diff = "$UNITDIR/$rev.zip";  $F_Ext = '.zip';
		$CMD1 = "cd $UNITDIR/cache; zip -r $F_Cache *";
		$CMD2 = "cd $UNITDIR ; zip -r $F_Diff en log add diff txt_rdiff" unless $rev <= 1;
	} elsif ($FMT eq 'tgz') {
		$F_Cache = "$UNITDIR/$rev-cache.tgz"; $F_Diff = "$UNITDIR/$rev.tgz";  $F_Ext = '.tgz';
		$CMD1 = "cd $UNITDIR/cache; tar cfz $F_Cache *";
		$CMD2 = "cd $UNITDIR ; tar cfz $F_Diff en log add diff txt_rdiff" unless $rev <= 1;
	} else {
		$F_Cache = "$UNITDIR/cache";
		$F_Diff = "$UNITDIR/en $UNITDIR/log $UNITDIR/add $UNITDIR/diff $ENT_DIR/txt_rdiff";
		$F_Ext = '';
	}
	if ($CMD1) { local $ENV{PWD}; print $CMD1,"\n" if $CONF{trace} > 2; system "($CMD1) 2> /dev/null"; }
	if ($CMD2) { local $ENV{PWD}; print $CMD2,"\n" if $CONF{trace} > 2; system "($CMD2) 2> /dev/null"; }

	delete $EV{$UNIT};
	if (-d $SORTIE) { # utilisation de crpatch en direct, pas pour 'commit'
		system "mv $F_Diff $SORTIE/$UNIT-$rev$F_Ext; mv $F_Cache $SORTIE/$UNIT-$rev-cache$F_Ext";
		system 'rm', '-Rf', $UNITDIR unless $NODEL;
	}
}

