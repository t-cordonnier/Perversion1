package PV::Archive::ftp;

use Net::FTP;
use File::Basename;
use File::Temp;

@ISA = qw (PV::Archive);

sub new {
	my ($classe, %CONF) = @_;
	return bless { dir => $CONF{archive}, login => $CONF{login}, trace => $CONF{trace} };
}

sub connect {
	my ($self, $login, $pass) = @_;
	$login ||= $$self{login}; unless ($pass) { ($pass) = $1 if $login =~ s|/(.+)$||; }
	my ($host, $dir) = ($$self{dir} =~ m|^ftp://(.+?)/(.+)$|);
	print STDERR "connexion �$host, dir = $dir\n" if $$self{trace};
	$$self{obj} = new Net::FTP ($host, Debug => ($$self{trace} > 5)) or die "Erreur FTP : $@";
	$$self{obj}->login ($login, $pass) or die "FTP : Login incorrect\n";
	$$self{obj}->cwd ($dir) or die "Erreur FTP chdir\n";
	print "connect : ", $$self{obj}->pwd, "\n";
	return $$self{obj};
}

sub disconnect {
	my $self = shift;
	return $$self{obj}->quit;
}

sub makedir {
	my $self = shift;
	while (my $dir = shift) {
		$$self{obj}->mkdir ($dir, 1);
	}
}

sub isdir {
	my ($self, $dir) = @_;
	my @list = $$self{obj}->ls ($dir); shift (@list);
	return (@list > 1) or ($list[0] !~  /$dir$/);
}

sub exist {
	my ($self, $dir) = @_;
	my @list = $$self{obj}->dir($dir);
	return (@list > 1);
}

sub can_read {
	my ($self, $dir) = @_;
	return 1;
}

sub can_write {
	my ($self, $dir) = @_;
	return 1;
}

sub contenu {
	my ($self, $dir) = @_;
	my @LS = $$self{obj}->ls ($dir); return @LS;
}


sub put1 {
	my ($self, $src, $dest) = @_;
	$$self{obj}->put ($src, $dest);
}

sub get1 {
	my ($self, $src, $dest) = @_;
	$$self{obj}->get ($src, $dest);
}

sub ajoute {
	my ($self, $dest, $contenu) = @_; $dest = "$$self{dir}/$dest";
	open (DEST, "> tmp"); print DEST $contenu; close (DEST);
	$$self{obj}->append ('tmp', $dest);
	unlink 'tmp';
}

sub date_fichier {
	my ($self, $fichier) = @_;
	return $$self{obj}->mdtm($fichier);
}

sub taille_fichier {
	my ($self, $fichier) = @_;
	return $$self{obj}->size($fichier);
}

sub sup1 {
	my ($self, $dest) = @_;
	$$self{obj}->delete ($dest);
}

sub sLink {
	my ($self, $orig, $dest) = @_;
	$self->copie ($orig, $dest); # pas de liens symboliques
}

sub pLink {
	my ($self, $orig, $dest) = @_;
	$self->copie ($orig, $dest); # pas de liens symboliques
}

sub copie {
	my ($self, $orig, $dest) = @_;
	$$self{obj}->get ($orig, 'tmp');
	$$self{obj}->put ('tmp', $dest);
}

1;

