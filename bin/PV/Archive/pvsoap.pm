package PV::Archive::pvsoap;

@ISA = qw (PV::Archive);

use SOAP::Lite;

sub new {
	my ($classe, %CONF) = @_;
	return bless { dir => $CONF{archive}, login => $CONF{login}, trace => $CONF{trace} };
}

sub connect {
	my ($self, $login, $pass) = @_;
	$login ||= $$self{login}; unless ($pass) { ($pass) = $1 if $login =~ s|/(.+)$||; }
	my $proto = $$self{dir}; $proto =~ s/^pvsoap\+//; print STDERR "connexion �$proto\n" if $$self{trace};
	$proto =~ s|//|//$login:$pass\@| if $login and $pass;
	$$self{proxy} = SOAP::Lite->proxy ($proto)->uri ('urn:PV/Serv/Soap');
}

sub disconnect { my $self = shift; undef $$self{proxy}; undef $$self{obj}; }

sub makedir {
	my $self = shift;
	return $$self{proxy}->makedir (@_)->result;
}

sub isdir {
	my ($self, $dir) = @_;
	return $$self{proxy}->isdir ($dir)->result;
}

sub exist {
	my ($self, $dir) = @_;
	return $$self{proxy}->exist ($dir)->result;
}

sub can_read {
	my ($self, $dir) = @_;
	return $$self{proxy}->can_read ($dir)->result;
}

sub can_write {
	my ($self, $dir) = @_;
	return $$self{proxy}->can_write ($dir)->result;
}

sub contenu {
	my ($self, $dir) = @_;
	return $$self{proxy}->contenu ($dir)->result;
}


sub put1 {
	my ($self, $src, $dest) = @_;
	print STDERR "archive->put1($src,$dest)\n" if $$self{trace};
	local $/ = undef; open (EN, $src); my $src_content = <EN>; close (EN);
	my $RES = $$self{proxy}->put1 ($src_content, $dest);
	use Data::Dumper; print STDERR "Fault = ", Dumper($RES->fault);
	die $RES->fault if $RES->fault; return $RES->result;
}

sub get1 {
	my ($self, $src, $dest) = @_;
	my $content = $$self{proxy}->get1($src)->result;
	open (SOR, "> $dest"); print SOR $content; close (SOR);
}

sub ajoute {
	my ($self, $dest, $contenu) = @_; $dest = "$$self{dir}/$dest";
	return $$self{proxy}->ajoute ($dest, $contenu)->result;
}

sub date_fichier {
	my ($self, $fichier, $type) = @_;
	return $$self{proxy}->date_fichier ($fichier, $type)->result;
}

sub taille_fichier {
	my ($self, $fichier) = @_;
	return $$self{proxy}->taille_fichier ($fichier)->result;
}

sub sup1 {
	my ($self, $dest) = @_;
	return $$self{proxy}->sup1 ($dest)->result;
}

sub sLink {
	my ($self, $orig, $dest) = @_;
	return $$self{proxy}->sLink ($orig, $dest)->result;
}

sub pLink {
	my ($self, $orig, $dest) = @_;
	return $$self{proxy}->pLink ($orig, $dest)->result;
}

sub copie {
	my ($self, $orig, $dest) = @_;
	return $$self{proxy}->copie ($orig, $dest)->result;
}

1;
