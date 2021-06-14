package PV::Archive::file;

use File::Basename;
use File::Copy;
use File::Find;

@ISA = qw (PV::Archive);

sub new {
	my ($classe, %CONF) = @_;
	return bless { dir => $CONF{archive}, trace => $CONF{trace} };
}

sub connect { 1; }
sub disconnect { 1; }

sub makedir {
	my $self = shift;
	while (my $dir = shift) {
		print "archive->makedir($dir)\n" if $$self{trace} >= 2;
		my $parent = dirname($dir);
		$self->makedir($parent) unless -d "$$self{dir}/$parent";
		mkdir "$$self{dir}/$dir";
	}
}

sub isdir {
	my ($self, $dir) = @_;
	return -d "$$self{dir}/$dir";
}

sub exist {
	my ($self, $dir) = @_;
	return -e "$$self{dir}/$dir";
}

sub can_read {
	my ($self, $dir) = @_;
	return -r "$$self{dir}/$dir";
}

sub can_write {
	my ($self, $dir) = @_;
	if (-e "$$self{dir}/$dir") { return -w "$$self{dir}/$dir"; }
	else { return -w dirname("$$self{dir}/$dir"); }
}

sub contenu {
	my ($self, $dir) = @_;
	local *DIR; opendir (DIR, "$$self{dir}/$dir") or die "$dir";
	my @RES = grep { $_ !~ /^\./ } readdir(DIR); closedir (DIR);
	return @RES;
}


sub put1 {
	my ($self, $src, $dest) = @_;
	File::Copy::copy ($src, "$$self{dir}/$dest") and return 1;
}

sub get1 {
	my ($self, $src, $dest) = @_;
	File::Copy::copy ("$$self{dir}/$src", $dest);
}

sub ajoute {
	my ($self, $dest, $contenu) = @_; $dest = "$$self{dir}/$dest";
	open (DEST, ">> $dest"); print DEST $contenu; close (DEST);
}

sub date_fichier {
	my ($self, $fichier, $type) = @_;
	if ($type =~ /[Aa]/) { return time() - 86400 * -A "$$self{dir}/$fichier"; }
	if ($type =~ /[Cc]/) { return time() - 86400 * -C "$$self{dir}/$fichier"; }
	return time() - 86400 * -M "$$self{dir}/$fichier";
}

sub taille_fichier {
	my ($self, $fichier) = @_;
	return -s "$$self{dir}/$fichier";
}

sub sup1 {
	my ($self, $dest) = @_;
	unlink "$$self{dir}/$dest"; 
}

sub sLink {
	my ($self, $orig, $dest) = @_;
	my @dOrig = split('/',$orig); my @dDest = split ('/', $dest);
	my $idx = 0; while ($dOrig[$idx] eq $dDest[$idx]) { $idx++;  }
	my $destLnk = '../' x ($#dDest - $idx) . join ('/', @dOrig [$idx .. $#dOrig]);
	system "ln -s $destLnk $$self{dir}/$dest";
}

sub pLink {
	my ($self, $orig, $dest) = @_;
	system "ln $$self{dir}/$orig $$self{dir}/$dest";
}

sub copie {
	my ($self, $orig, $dest) = @_;
	system "cp -R $$self{dir}/$orig $$self{dir}/$dest";
}

sub liens {
	my ($self, $fichier) = @_;
	my @stat = stat ($fichier); 
	return $stat[3];
}

1;

