package PV::Serv;

use PV::Archive;
use PV::Conf;


sub evenements {
	my %ARGS = @_;
	my ($base) = PV::Conf::basedir;
	my $arch = $ARGS{aref} || create PV::Archive (%ARGS);  $arch->connect; 
	$arch->get("$ARGS{projet}/ev", "$base/.pver/s.ev") or die "Pas d'événements dans archive\n";
	$arch->disconnect unless $arch == $ARGS{aref};
	open (EV, "$base/.pver/s.ev") or die "Impossible de lire les événements\n"; my %RES = ();
	while (<EV>) {
		my ($date, $unit, $branche, $ver) = split (/\t/);
		$RES{$unit}{$branche}[$ver] = $date;
	}
	return %RES;
}

1;


