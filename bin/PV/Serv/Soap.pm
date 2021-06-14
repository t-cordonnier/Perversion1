package PV::Serv::Soap;

use PV::Archive;

our $ARCHIVE = undef;

sub init {
	my (undef, %args) = @_;
	$ARCHIVE = create PV::Archive (%args)
		or die "Archive manquante ou non sp�ifi�";
}

sub makedir {
	my ($self, @reps) = @_;
	return $ARCHIVE->makedir (@reps);
}

sub isdir {
	my ($self, $dir) = @_;
	return $ARCHIVE->isdir($dir);
}

sub exist {
	my ($self, $dir) = @_;
	return $ARCHIVE->exist ($dir);
}

sub can_read {
	my ($self, $dir) = @_;
	return $ARCHIVE->can_read ($dir);
}

sub can_write {
	my ($self, $dir) = @_;
	return  $ARCHIVE->can_write ($dir);
}

sub contenu {
	my ($self, $dir) = @_;
	return $ARCHIVE->contenu ($dir);
}


sub put1 {
	my ($self, $src_content, $dest) = @_;
	open (DEST, "> .tmp_file") or die "tmp_file"; print DEST $src_content; close (DEST);
	my $RES = $ARCHIVE->put1 ('.tmp_file', $dest);
	unlink '.tmp_file'; return $RES;
}

sub get1 {
	my ($self, $src) = @_;
	$ARCHIVE->get1 ($src, '.tmp_file') or die $@;
	local $/ = undef; open (EN, '.tmp_file'); my $src_content = <EN>; close (EN);
	unlink '.tmp_file'; return $src_content;
}

sub ajoute {
	my ($self, $dest, $contenu) = @_;
	return $ARCHIVE->ajoute ($dest, $contenu);
}

sub date_fichier {
	my ($self, $fichier, $type) = @_;
	return $ARCHIVE->date_fichier ($fichier, $type);
}

sub taille_fichier {
	my ($self, $fichier) = @_;
	return $ARCHIVE->taille_fichier ($fichier);
}

sub sup1 {
	my ($self, $dest) = @_;
	return $ARCHIVE->sup1($dest);
}

sub sLink {
	my ($self, $orig, $dest) = @_;
	return $ARCHIVE->sLink ($orig, $dest);
}

sub pLink {
	my ($self, $orig, $dest) = @_;
	return $ARCHIVE->pLink ($orig, $dest);
}

sub copie {
	my ($self, $orig, $dest) = @_;
	return $ARCHIVE->copie ($orig, $dest);
}

1;
