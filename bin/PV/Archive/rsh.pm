package PV::Archive::rsh;

use File::Remote;

@ISA = qw (PV::Archive);

sub new {
	my ($classe, %CONF) = @_;
	my ($host, $rep) = ($CONF{archive} =~ m|^rsh://(.+?)/(.+)|);
	my %PARAMS = (rsh => $CONF{rsh}, rcp => $CONF{rcp});
	return bless { host => $host, rep => $rep, dir => "$host:$rep", obj => new File::Remote(%PARAMS) };
}

sub connect {
	my ($self, $login, $pass) = @_;
	$$self{login} = $login if $login; $$self{pass} = $pass if $pass;
	return $$self{login};
}

sub disconnect {1;}

sub makedir {
	my $self = shift;
	while (my $dir = shift) {
		print "archive->makedir($dir)\n" if $$self{trace} >= 2;
		$$self{obj}->mkdir ("$$self{dir}/$dir", 1);
	}
}

sub isdir {
	my ($self, $dir) = @_;
	open (DIR, $$self{obj}->setssh . " $$self{host} file $dir |") or die "$dir";
	my $RES = <DIR>; close (DIR);
	return ($RES =~ /directory/i); 
}

sub contenu {
	my ($self, $dir) = @_;
	open (DIR, $$self{obj}->setssh . " $$self{host} ls $$self{rep}/$dir |") or die "$dir";
	my @RES = <DIR>; foreach (@RES) { s/\n$//; } close (DIR);
	return @RES;
}


sub put1 {
	my ($self, $src, $dest) = @_;
	$$self{obj}->copy ($src, "$$self{dir}/$dest");
}

sub get1 {
	my ($self, $src, $dest) = @_;
	$$self{obj}->copy ("$$self{dir}/$src", $dest);
}

sub ajoute {
	my ($self, $dest, $contenu) = @_; $dest = "$$self{host}:$$self{dir}/$dest";
	$$self{obj}->append ("$$self{dir}/$dest", $contenu);
}

sub date_fichier {
	my ($self, $fichier) = @_;
	return -M "$$self{dir}/$fichier";
}

sub sup1 {
	my ($self, $dest) = @_;
	$$self{obj}->unlink ("$$self{dir}/$dest");
}



1;

