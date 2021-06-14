package PV::Conf;

=item PV::Conf::basedir();
	remonte dans l'arborescence jusqu'à la racine du référentiel local
	renvoie ($dir, $prefix) =
		$dir : répertoire de base
		$prefix : à ajouter devant le nom des fichiers
=cut
sub basedir {
	my $PWD = shift || $ENV{PWD}; my $prefix = '';
	while (! -e "$PWD/.pver") {
		die "Impossible de trouver le répertoire racine" if $ENV{PWD} eq '/';
		my $idx = rindex($PWD,'/'); my $ap = substr($PWD, $idx + 1);
		$prefix = "$ap/$prefix"; chdir '..'; $PWD = substr($PWD,0, $idx);
	}
	$prefix =~ s|/$||g;
	return ($PWD, $prefix);
}

=item PV::Conf::ecrire (\%conf, $dest, $nom)
	écrit la configuration
=cut
sub ecrire (\%$$) {
	my ($CONF, $dest, $nom) = @_;
	use Data::Dumper; my $DUMP = Dumper ($CONF);
	$DUMP =~ s|\$VAR1|\%$nom|; $DUMP =~ s|=\s+\{|= \(|; $DUMP =~ s|\};|\);|;
	open (CONF, "> $dest") or die "Impossible de créer $dest\n";
	print CONF $DUMP; close (CONF);
}


1;

