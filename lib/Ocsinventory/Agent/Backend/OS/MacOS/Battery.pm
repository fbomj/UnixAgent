package Ocsinventory::Agent::Backend::OS::MacOS::Battery;

use strict;
use warnings;
use POSIX;

use English qw( -no_match_vars ) ;

sub check {
    my $params = shift;
    my $common = $params->{common};
    return $common->can_run ("/usr/sbin/system_profiler");
}

my $serial;
my $name;
my $manufacturer;
my $designvoltage;
my $cycle;
my $estimated;
my $state;

sub run {
    my $params = shift;
    my $common = $params->{common};

    my @battery_info = `/usr/sbin/system_profiler SPPowerDataType`;

    foreach my $info (@battery_info) {
        $name=$1 if ($info =~ /^Device Name:\s(.*)/);
        $serial=$1 if ($info =~ /^Serial Number:\s(.*)/);
        $manufacturer=$1 if ($info =~ /^Manufacturer:\s(.*)/);
        $designvoltage=ceil($1/1000) if ($info =~ /^Voltage (mV):\s(.*)/);
        $cycle=$1 if ($info =~ /^Cycle Count:\s(.*)/);
        $estimated=$1 if ($info =~ /^Charge Remaining (mAh):\s(.*)/);
        $state=$1 if ($info =~ /^Condition:\s(.*)/);
    }
  
    # Push power and battery informations to xml
    # all apple batteries are Lithium-Ion
    $common->addBatteries({
        CHEMISTRY                => 'Lithium-ion',
        CYCLES                   => $cycle,
        DESCRIPTION              => 'N/A',
        DESIGNCAPACITY           => $designvoltage." V",
        DESIGNVOLTAGE            => $designvoltage." V",
        ESTIMATEDCHARGEREMAINING => $estimated,
        MANUFACTURER             => $manufacturer,
        NAME                     => $name,
        SERIALNUMBER             => $serial,
        STATUS                   => $state,
    });
}

1;
