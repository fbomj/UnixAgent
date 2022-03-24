package Ocsinventory::Agent::Backend::OS::Generic::OS;

use strict;
use warnings;

sub check {
    my $params = shift;
    my $common = $params->{common};

    if ($common->can_run("stat")) {
        return 1;
    } else {
        return 0;
    }
}

# Initialise the distro entry
sub run {
    my $params = shift;
    my $common = $params->{common};

    my $installdate;
    my $idate=`stat -c %w /`;
    $installdate = $1 if ($idate =~ /^(\d+-\d+-\d+)/);

    $common->setHardware({
        INSTALLDATE => $installdate
    });
}

1;
