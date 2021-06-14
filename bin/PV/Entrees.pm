package PV::Entrees; 

use File::Copy; 

sub lire {
	my ($basedir, $ref) = @_; my %ENTREES = (); 
	if (open (EEN, "$basedir/.pver/$ref/en")) { 
		my $cur_unit = 'global'; 
		while (my $ligne = <EEN>) {
			chop($ligne); 
			if ($ligne =~ m|^<(\w+)>$|) { $cur_unit = $1; $ENTREES{$cur_unit} ||= []; }
			else { push (@{$ENTREES{$cur_unit}}, [split (/\t/, $ligne)]); }
		}
		close (EEN); 
	} 
	return %ENTREES; 
}

sub ecrire {
	my ($basedir, $ref, $annul, %ENTREES) = @_; 

	while ($annul) {
		unlink "$basedir/.pver/$ref/en.$annul";
		my $orig = "$basedir/.pver/$ref/en." . ($annul-1); $orig =~ s/\.0$//;
		File::Copy::move ($orig, "$basedir/.pver/$ref/en.$annul");
		$annul--; 
	}
	
	open (SEN, "> $basedir/.pver/$ref/en") or die "Ecriture impossible dans .pver/$ref/en";
	while (my ($unit, $tab) = each (%ENTREES)) {
		print SEN "<$unit>\n"; 
		foreach $ent (sort { ${$a}[2] cmp ${$b}[2] } @$tab) {
			print SEN join ("\t", @$ent), "\n";
		}
	}
	close (SEN);
}

sub trouve {
	my ($fichier, $id, %ENTREES) = @_; my %SORTIES = ();
	while (my ($UNIT, $TAB) = each(%ENTREES)) {
		foreach my $ENTR (@$TAB) {
			$SORTIES{$UNIT} = $ENTR if ${$ENTR}[$id] eq $fichier;
		}
	}
	return %SORTIES; 
}

1;
