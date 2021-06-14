package PV::Local;

use File::Basename; 

use Exporter; @ISA = qw(Exporter);
@EXPORT = qw (&copier_fichier &prune &mkdir_rec &substitutions &date_analyse) ;

sub copier_fichier {
	my ($fmt, $fic, $dest, $orig) = @_; $orig ||= '.';
	my $base = dirname("$dest/$fic"); mkdir_rec ($base) unless -e $base;
	if ($fmt eq 'dir') { mkdir_rec ("$dest/$fic"); }
	elsif ($fmt eq 'tar') {
		mkdir_rec ("$dest/$fic");
		system "cd $dest/$fic; tar xvf $DIR/$fic";
	} elsif ($fmt eq 'zip') {
		mkdir_rec ("$dest/$fic");
		system "cd $dest/$fic; unzip $DIR/$fic";
	} elsif ($fmt eq 'lnk') {
		if (system "ln -s $orig/$fic $dest/$fic") {
			# si le système ne supporte pas les liens symboliques, les remplacer par un fichier
			open (FIC, "$dest/$fic"); print FIC readlink($fic); close (FIC);
		}
	} elsif (-e $fic) { # fmt = 'txt' ou 'bin'
		print STDERR "copy $orig/$fic $dest/$fic\n" if $main::CONF{trace} > 4;
		system ('cp', "$orig/$fic", "$dest/$fic");
	} else {
		$fic =~ s|/+|/|g; # pour éviter une confusion
		die "Fichier '$fic' introuvable (origine $orig) : supprimez-le du rï¿œï¿œentiel ou rï¿œupï¿œez-le.\n";
	}
}

# -- prune($dir) : supprime les répertoires vides
sub prune {
	my $dir = shift; my $cpt = 0; local *PRUNEDIR;
	opendir (PRUNEDIR, $dir) or return;
	while (my $sub = readdir(PRUNEDIR)) {
		next if $sub =~ /^\./;
		$sub = "$dir/$sub";
		if (-d $sub) { &prune ($sub); $cpt++ if -e $sub; }
		else { $cpt++; }
	}
	closedir (PRUNEDIR);
	print STDERR "prune($dir) : $cpt\n" if $CONF{trace} > 4;
	rmdir $dir unless $cpt;
}

sub mkdir_rec {
	system 'mkdir', '-p', $_ foreach @_;
}

# -- substitutions(fic)
# Remplace les items [PVER:XXX...]
sub substitutions {
	my ($fic, %args) = @_; $args{AUTEUR} ||= "<$ENV{LOGNAME}\@$ENV{HOSTNAME}>";
	if ($args{DATE} =~ /^[Cc]/) {
		$args{DATE} = time() - 86400 * -C $fic; 
	} elsif ($args{DATE} =~ /^[Aa]/) {
		$args{DATE} = time() - 86400 * -A $fic; 
	} elsif ($args{DATE} =~ /^[Mm]/) {
		$args{DATE} = time() - 86400 * -M $fic; 
	} elsif (! $args{DATE}) {
		$args{DATE} = time(); 
	} elsif ($args{DATE} =~ m|^\d+/|) {
		($args{DATE}) = analyse_date($args{DATE});
	} 
	my @TIME = localtime($args{DATE}); $TIME[4] ++; $TIME[5] += 1900;
	$args{DATE} = sprintf ('%04i/%02i/%02i %02i:%02i:%02i', @TIME [5,4,3,2,1,0]);
	
	if ((-T $fic) && open (FEN, $fic)) {		
		local $/ = undef; my $TXT = <FEN>; close (FEN); 
		my $fic_court = $fic; $fic_court =~ s|^\.pver/\w+/clone/||;
		my $modifs = $TXT =~ s{\[PVER:([\w\+]+)\s.*?\]} {"[PVER:$1 " .
			join (' ', map {
				($_ eq 'Id') ? join(':', $args{PROJET}, $args{UNITE}, $fic_court)
				: ($_ =~ /^Fi(le|chier)$/) ? $fic_court
				: ($_ =~ /^Proj(ec?t)?$/) ? $args{PROJET}
				: ($_ =~ /^Unité?$/) ? $args{UNITE}
				: ($_ eq 'Date') ? $args{DATE}
				: ($_ =~ /^URev(ision)?$/) ? join(':', @args{'BRANCHE','REV'}) 
				: ($_ =~ /^Aut(eur|hor)?$/) ? $args{AUTEUR} 
				: ""
			} split (/\+/, $1))
		. "]"}gex;
		if ($modifs) { unlink $fic; open (FSO, "> $fic"); print FSO $TXT; close (FSO); }
	}
}	

sub analyse_date ($) {
	my $DATE = shift;
	if ($DATE =~ /^[AaCcMm]/) { return ($DATE, $DATE); } # utilisation des dates d'accès, de modification et de changement
	elsif ($DATE =~ m|(\d+)/(\d+)/(\d+)|) {
		my ($Y, $M, $D) = ($1,$2,$3); 
		($Y, $D) = ($D, $Y) if $D > 31 and $Y < 31;
		$Y += 1900 if $Y < 100; $Y += 100 if $Y < 1950; 
		my $DATE00 = "$DATE:00"; my ($h, $m, $s) = ($DATE00 =~ m|(\d+):(\d+):(\d+)|);
		use Time::Local; $DATE = timelocal ($s,$m,$h,$D,$M - 1,$Y);
	} elsif ($DATE =~ /^\d+$/) {
		# date EPOCH : rien à faire
	} else {
		$DATE = time(); # date système
	}
	my @TIME = localtime($DATE); $TIME[4] ++; $TIME[5] += 1900;
	my $DATESTR = sprintf ('%04i/%02i/%02i %02i:%02i:%02i', @TIME [5,4,3,2,1,0]);
	return ($DATE, $DATESTR);
}

sub messages {
	my ($command, $lang) = @_;
	my $fic = _msgdir($command,$lang);
	open (ENTREE, $fic); my %SORTIE;
	my ($cle, $valeur);
	while (<ENTREE>) {
		if (m|<(.+)>|) { chop($valeur); $SORTIE{$cle} = $valeur; $cle = $1; $valeur = ''; }
		else { $valeur .= $_; }
	}
	chop($valeur); $SORTIE{$cle} = $valeur; 
	close (ENTREE); return %SORTIE;
}

sub _msgdir {
	my ($commande, $lang) = @_;
	$lang ||= $ENV{LANG} || $ENV{LANGUAGE} || $ENV{LC_MESSAGES};
	my @lang = split(/:/, $lang); my $fic;
	foreach (@lang) {
		my ($lg, $pays, $code) = (m|^(\w\w\w?)(?:_(\w\w))?(?:\.(.+))?$|); 
		$fic = "$main::PVBINDIR/messages/${lg}_$pays.$code/$commande.txt"; return $fic if -e $fic;
		$fic = "$main::PVBINDIR/messages/${lg}.$code/$commande.txt"; return $fic if -e $fic;
		$fic = "$main::PVBINDIR/messages/${lg}_$pays/$commande.txt"; return $fic if -e $fic;
		$fic = "$main::PVBINDIR/messages/${lg}/$commande.txt"; return $fic if -e $fic;
	}
}

1;
