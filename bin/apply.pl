use File::Basename;
use Getopt::Long;
use PV::Local; 

my $DIR = $ENV{PWD};
$DIR = dirname($DIR) until -e "$DIR/.pver" or ($DIR =~ /^\./ or !$DIR);
do "$DIR/.pver/conf.pl" unless %CONF;

my ($PATCH, $REF, $CLONE, $VER, $UNIT);
GetOptions (
	'patch|p:s' => \$PATCH, 'ref|R:s' => \$REF, 
	'unit|U:s' => \$UNIT, 'ver|v:i' => \$VER,
	'clone|c' => \$CLONE,
);
my %MESSAGES = PV::Local::messages('apply');
$PATCH ||= shift || die "$MESSAGES{syntaxe}\n";
$CLONE &&= '--clone'; $REF ||= $CONF{defaultref}; my $REFDIR = "$DIR/.pver/$REF";

if ($PATCH =~ /^(\w+):([\w\/]+):(\d+)$/) {
	my ($unit0, $branche0, $rev0) = ($1, $2, $3); my $REFCFG = $CONF{ref}{$REF};
	require PV::Archive; my $arch = create PV::Archive (%$REFCFG); 
	$arch->connect() or die "$MESSAGES{err_connect_ref} $REF\n";
	print STDERR "$$REFCFG{projet}/$unit0/$branche0/$rev0.tgz\n";
	my $idx = rindex($branche0, '/'); my $branche1 = $branche0; $branche1 = substr($branche1,$idx + 1) if $idx > 0;
	$arch->get ("$$REFCFG{projet}/$unit0/$branche0/$rev0.tgz", ".pver/$unit0-$branche1-$rev0.tgz");
	$PATCH = ".pver/$unit0-$branche1-$rev0.tgz";
}
my $PATCH_DIR = $PATCH;
unless (-d $PATCH) {
	$PATCH_DIR = "$DIR/.pver/" . basename($PATCH) . '_tmp'; mkdir $PATCH_DIR;
	print STDERR "mkdir $PATCH_DIR\n" if $CONF{trace} > 0;
	if ($PATCH =~ /\.zip$/) { &p_system ('unzip', '-d', $PATCH_DIR, $PATCH); }
	elsif ($PATCH =~ /\.tar$/) { &p_system ('tar', 'xf',  $PATCH, '--directory', $PATCH_DIR); }
	elsif ($PATCH =~ /\.tgz$/) { &p_system ('tar', 'xfz', $PATCH, '--directory', $PATCH_DIR); }
	else { die "$MESSAGES{err_patch_impossible} $PATCH : $MESSAGES{err_patch_format}.\n"; }
}


## -------------- à partir de maintenant, nous sommes dans le cas "répertoire" ------------

use PV::Entrees; our %ENTREES = PV::Entrees::lire ($DIR, $REF); # entrées dans le référentiel (pas dans le patch!) 
my @UNITES;  # unités à patcher
if ($UNIT =~ /,/) { @UNITES = split(/,/, $UNIT); } elsif ($UNIT) { @UNITES = ($UNIT); } else { @UNITES = keys (%ENTREES); }
my @PENTREES = (); if (open (PEN, "$PATCH_DIR/en")) {
	while (<PEN>) { chop; push (@PENTREES, [split(/\t/, $_)]); }
	close (PEN); 
}


our $DATE, $AUTEUR;
if (open (LOG, "$REFDIR/log")) {
	while (<LOG>) {
		if (m|^\[DATE\]\s+(.+)\n|) { $DATE = $1; }
		elsif (m|^\[AUTEUR\]\s+(.+)\n|) { $AUTEUR = $1; }
		elsif (m|^\[VERSION\]\s+(.+)\n|) { $VER ||= $1; }
	}
	close (LOG);
}

&apply_to_files('.', 0); &apply_to_files ("$DIR/.pver/$REF/clone", 1) if $CLONE;
foreach my $TABLE (@ENTREES{@UNITES}) {
	foreach my $E (@$TABLE) {
		my ($PE) = grep { ${$_}[2] eq ${$E}[-1] } @PENTREES; next unless $PE;
		if ($CLONE) { # Les nouvelles entrées pointent vers le nouveau répertoire
			@{$E} = ('.', ${$E}[1], ${$PE}[-1]);
		} else { # Les nouvelles entrées recopient les déplacements signalés dans @PENTREES
			${$E}[0] = ${$PE}[0]; push (@$E, ${$PE}[-1]) unless ${$E}[-1] eq ${$PE}[-1];
		}
	}
	@$TABLE = grep { ${$_}[0] ne '-' } @$TABLE if $CLONE; # Effacer les entrées de fichiers supprimés
	push (@$TABLE, grep { ${$_}[0] eq '+' } @PENTREES);
}
PV::Entrees::ecrire ($DIR, $REF, $CONF{annul}, %ENTREES);
system ('rm', '-Rf', $PATCH_DIR) unless $PATCH_DIR eq $PATCH;



sub apply_to_files {
	my ($LOCAL_DIR, $LOCAL_CLONE) = @_;
	print main::STDERR "$PATCH_DIR > $LOCAL_DIR\n" if $CONF{trace} > 2;
		
	foreach my $E (@PENTREES) { 
		PV::Local::substitutions("$LOCAL_DIR/${$E}[2]") if -T ${$E}[2]; 
		PV::Local::substitutions("$LOCAL_CLONE/${$E}[2]") if -T ${$E}[2]; 
	}

	# 1. Appliquer le patch textuel, optimisé
	if (-e "$PATCH_DIR/txt_rdiff") {
		# Protège le patch contre un problème de substitutions
		PV::Local::substitutions ("$PATCH_DIR/txt_rdiff");
		# Applique le patch
		my $cmd = "patch -p0 -b -V simple -z .orig -f -d $LOCAL_DIR < $PATCH_DIR/txt_rdiff";
		if ($CONF{trace} > 2) { print STDERR $cmd; } # elsif ($CONF{trace} < 1) { $cmd .= " > /dev/null 2> /dev/null"; } 
		&p_system ($cmd);
	}
	
	# 2. Déplacer et copier les fichiers (sauf répertoires) qui sont marqués comme tels dans le patch
	foreach my $E (@PENTREES) { # reverse sort { ${$a}[-1] cmp ${$b}[-1] } @PENTREES?
		if (${$E}[0] eq '>') {
			my $dir0 = "$LOCAL_DIR/" . dirname (${$E}[-1]); mkdir $dir0 unless -d $dir0;
			if (${$E}[1] eq 'dir') { mkdir "$LOCAL_DIR/${$E}[-1]"; } 
			else { &p_system ('mv', "$LOCAL_DIR/${$E}[2]" => "$LOCAL_DIR/${$E}[-1]"); }
		} elsif (${$E}[0] eq '=') {
			my $dir0 = dirname (${$E}[-1]); mkdir $dir0 unless -d $dir0;
			if (${$E}[1] eq 'dir') { mkdir "$LOCAL_DIR/${$E}[-1]"; } 
			else {	# Partir toujours du fichier d'origine
				my $ORIG = ${$E}[2]; $ORIG = "$ORIG.orig" if -e "$ORIG.orig";
				&p_system ('cp', "$LOCAL_DIR/$ORIG" => "$LOCAL_DIR/${$E}[-1]");
			}
		}
	}
	
	# 3. Appliquer les différences
	foreach my $E (@PENTREES) {
		if (${$E}[0] eq '+') {
			if (${$E}[1] eq 'dir') { &p_system ('mkdir', '--parents', "$LOCAL_DIR/${$E}[-1]"); }
			else { &p_system ('cp', "$PATCH_DIR/add/${$E}[-1]" => "$LOCAL_DIR/${$E}[-1]"); }
		} elsif (${$E}[0] ne '-') { # Le fichier existait déjà, on regarde s'il a été modifié ou non
			my $DEST = ${$E}[-1]; my $PATCH_FIC = "$PATCH_DIR/diff/$DEST";
			if (${$E}[1] eq 'dir') { next; } # le cas a été traité lors de la passe précédente
			elsif (-e $PATCH_FIC) { &p_system ('cp', $PATCH_FIC => "$LOCAL_DIR/$DEST"); } # Fichier trop gros
			elsif (-e "$PATCH_FIC.diff") { # Différence textuelle
				PV::Local::substitutions ("$PATCH_FIC.diff");
				&p_system ("patch '$LOCAL_DIR/$DEST' < '$PATCH_FIC.diff'"); 
			} 
			elsif (-e "$PATCH_FIC.bsdiff") { # Différence binaire
				if ($LOCAL_CLONE) {
					&p_system ('bspatch', "$LOCAL_DIR/$DEST" => "$LOCAL_DIR/$DEST.tmp", "$PATCH_FIC.bsdiff");
					unlink "$LOCAL_DIR/$DEST"; &p_system ('mv', "$LOCAL_DIR/$DEST.tmp", "$LOCAL_DIR/$DEST");
				} else { # Plus compliqué car le fichier a pu être modifié localement
					# on applique le patch sur une copie de ce qui est dans le clone
					my $CLONE_DIR = "$LOCAL_DIR/.pver/$REF/clone";
					&p_system ('bspatch', 
						"$CLONE_DIR/${$E}[2]" => "$LOCAL_DIR/$DEST.dans_pver", 
						"$PATCH_FIC.bsdiff");
					if (-T $DEST) { # on essaye un merge						
						&p_system ('merge', "$LOCAL_DIR/$DEST",
							"$CLONE_DIR/${$E}[2]", "$LOCAL_DIR/$DEST.dans_pver")
								or unlink "$LOCAL_DIR/$DEST.dans_pver";
					} else { # Impossible de faire un merge, mais...
						unless (&p_system ("diff '$CLONE_DIR/${$E}[2]' '$LOCAL_DIR/$DEST' > /dev/null")) {	
							# S'il n'y a aucune différence, aucune raison de garder le fichier local
							unlink "$LOCAL_DIR/$DEST"; 
							system 'mv',  "$LOCAL_DIR/$DEST.dans_pver" =>  "$LOCAL_DIR/$DEST";
						}
						# Sinon : conserver les deux fichiers car impossible de faire un merge
					}
				}
			}
			# --- si aucun des trois fichiers n'existe, c'est qu'il n'y a pas lieu de s'occuper de ce fichier.
		}
	}
	
	# 4. Supprimer les fichiers devenus inutiles
	foreach my $E (reverse sort { ${$a}[2] cmp ${$b}[2] } @PENTREES) {
		if (${$E}[1] eq 'dir') {
			system 'rm', '-Rf', "$LOCAL_DIR/${$E}[2]" if
					(   (${$E}[0] eq '>')  	# Répertoires déplacés
					or (${$E}[0] eq '-'))	# Répertoires supprimés
				 and ! # Ne supprime pas ce qui existe dans d'autres unités
				 	( grep { ${$_}[-1] eq ${$E}[2] } map { @$_ } values (%ENTREES) );
		} else {
			unlink ${$E}[2] if ${$E}[0] eq '-'; # Fichier supprimé
		}
	}
	system "find $LOCAL_DIR -name '*.orig' | xargs rm -f"; # Fichiers .orig
}

sub p_system {
	print main::STDERR join(' ',@_) if $CONF{trace} > 4;
	if (@_ < 2) { return system $_[0]; } # mode avec shell
	else { return system @_; } # mode sans shell
}

