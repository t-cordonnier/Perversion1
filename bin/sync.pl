use PV::Conf;
use PV::Archive;
use PV::Serv;

use Getopt::Long;
use File::Copy;



my ($REF, $UNIT, $DATE, $TAG, $BRANCHE);
GetOptions (
	'ref|R:s' => \$REF, 
	'unit|U:s' => \$UNIT,
	'date|D:s' => \$DATE,
	'branche|B:s' => \$BRANCHE,
);
my @UNIT = split(/,/, $UNIT); print "Unité : $UNIT\n" if $UNIT;
our ($DIR) = PV::Conf::basedir(); do "$DIR/.pver/conf.pl";
$REF ||= $CONF{defaultref};
my $REFCFG = $CONF{ref}{$REF}; my $REFDIR = "$DIR/.pver/$REF";

if ($DATE =~ m|(\d+)/(\d+)/(\d+)|) {
	require Time::Local;
	my ($Y, $M, $D) = ($1, $2, $3); my ($h, $m, $s) = (0, 0, 0);
	($h, $m, $s) = ($1, $2, $3) if $DATE =~ m|(\d+):(\d+):(\d+)|;
	$DATE =  Time::Local::timelocal ($s, $m, $h, $D, $M - 1, $Y);
}


my $aref = create PV::Archive (%$REFCFG); $aref->connect;

if ($aref->exist ('sconf.pl')) {
	$aref->get ('sconf.pl', '.pver/sconf.pl');
	do '.pver/sconf.pl'; unlink '.pver/sconf.pl';
	$CONF{ref}{$REF}{serv} = \%SCONF;
}

my %GET;
if ($TAG) {
	$arch->get ("$$REFCFG{projet}/tags", '.pver/tags');
	open (TAGS, '.pver/tags');
	while (<TAGS>) {
		my ($ltag, @refs) = split (/\t/);
		next unless $TAG eq $ltag;
		while (my $ref = shift(@refs)) {
			my ($unit, $branche, $rev) = split(':', $ref);
			next if $UNIT and ! (grep { $_ eq $unit } @UNIT);
			$GET{$unit} = [$branche, $rev];
		}
		last;
	}
	unlink '.pver/tags';
} else {
	my %EV = PV::Serv::evenements ('aref' => $aref, projet => $$REFCFG{projet});
	while (my ($unit, $ref1) = each (%EV)) {
		next if $UNIT and ! (grep { $_ eq $unit } @UNIT);
		my $branche0 = $BRANCHE || $$REFCFG{unit}{$unit}[0];
		my @rev = @{$$ref1{$branche0}};
		if ($DATE) {
			my $min = 0;
			REV: for (my $i = 1; $i < $#rev; $i++) {
				if ($rev[$i] <= $DATE) { $min = $i; } else { last REV; }
			}
			$GET{$unit} = [$branche0, $min] unless $min == 0;
		} else {
			$GET{$unit} = [$branche0, $#rev] if @rev;
		}
	}
}

my $ext = $SCONF{format}; $ext = '.' . $ext if $ext;
while (my ($unit, $ver) = each (%GET)) {
	next if $UNIT and ! (grep { $_ eq $unit } @UNIT);
	next unless $$ver[1]; # ne pas sortir les unités vides
	my ($branche0, $refbase) = @{$$REFCFG{unit}{$unit}}; my $enFic, $sorFic;
	print "$unit (branche $branche0) : $refbase ==> $$ver[1]\n";
	while ($refbase < $$ver[1]) {
		$refbase++; $enFic = "$$REFCFG{projet}/$unit/$branche0/${refbase}$ext";
		print "\tARCH diff : $enFic\n";
		$aref->get ($enFic, $sorFic = ".pver/$unit-${revbase}$ext");
		system 'pver', 'apply', '--patch', $sorFic,
				'--ref', $REF, '--ver', $refbase, '--clone';
		# local @ARGV = ($sorFic); do 'apply.pl';
		unlink $sorFic;
	}
}

$CONF{ref}{$REF}{unit} = \%GET;
PV::Conf::ecrire (%CONF, '.pver/conf.pl', 'CONF');

