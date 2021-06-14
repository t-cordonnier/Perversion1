use PV::Archive;
use File::Copy;

my $URL = shift or die "Syntaxe : $0 url-archive login pwd";
my $FIC = shift || $0;

my $archive = create PV::Archive (archive => $URL, trace => 10);
$archive->connect (shift, shift) or die "Connexion impossible :$@";
print "Connexion OK\n";
copy ($FIC, "tmp1");
$RES = $archive->put ("tmp1", "test-archive");
print "RES = $RES\n";  if ($@) { die "PUT : $@"; } else { print "put OK\n"; }
$archive->get ("test-archive", "tmp2"); print "get OK\n";
system "diff tmp1 tmp2"; # unlink "tmp1", "tmp2";
$archive->supprime ("test-archive"); 
$archive->disconnect;

