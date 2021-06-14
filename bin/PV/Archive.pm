package PV::Archive;

use POSIX(tmpnam);
use File::Basename;


sub create {
	my ($classe, %CONF) = @_;
	die "Archive manquante" unless $CONF{archive}; 
	my ($protocole) = ($CONF{archive} =~ m|^(\w+)(\+\w+)*\://|);
	$protocole = lc($protocole) || 'file';
	require "PV/Archive/$protocole.pm";
	return "PV::Archive::$protocole"->new (%CONF);
}

=item $archive->put ($src, $dest)
	Copie un fichier ou un r�ertoire vers l'archive
=cut
sub put {
	my ($self, $src, $dest) = @_;
	print "archive->put($src,$dest)\n" if $$self{trace} >= 2;
	my $parent = dirname($dest); $self->makedir($parent) unless ($parent =~ /^\./) or $self->isdir($parent);
	if (-d $src) {
		$self->makedir($dest); my $RES = 1;
		local *DIR; opendir (DIR, $src) or die "die:opendir($src)\n";
		while (my $f = readdir(DIR)) {
			$RES &&= $self->put ("$src/$f", "$dest/$f") unless $f =~ /^\./;
		}
		closedir (DIR);
	} else {
		return $self->put1 ($src, $dest);
	}
}

sub get {
	my ($self, $src, $dest) = @_;
	if ($self->isdir ($src)) {
		my @CONTENU = $self->contenu ($src);
		my $base = substr($src, rindex($src, '/') + 1);
		while (my $f = shift(@CONTENU)) {
			$self->get ("$src/$f", "$dest/$base");
		}
	} else {
		$self->get1 ($src, $dest);
	}
}

sub supprime {
	my ($self, $src) = @_;
	if ($self->isdir ($src)) {
		my @CONTENU = $self->contenu ($src);
		while (my $f = shift(@CONTENU)) {
			$self->supprime ("$src/$f");
		}
	}
	print "archive->sup ($src)\n" if $$self{trace} >= 2;
	$self->sup1 ($src);
}

sub liens { return 1; } # valeur par défaut

1;
