package Ocsinventory::Agent::Backend::OS::Generic::Screen;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use Data::Dumper;
my %pnp_db;

sub _find_pnp_ids {
    my @paths = (
        "/usr/share/hwdata/pnp.ids",
        "/usr/share/misc/pnp.ids",
        "/usr/share/pnp.ids",
        "/usr/local/share/pnp.ids"
    );

    foreach my $path (@paths) {
        return $path if -f $path;
    }
    return undef;
}

sub _load_pnp_ids {
    my $file = _find_pnp_ids();
    return {} unless $file;

    my $current_vendor;
    open my $fh, '<', $file or return {};

    while (<$fh>) {
        chomp;
        next if /^#/ || /^\s*$/;

        if (/^([A-Z0-9]{3})\s+(.+)/) {
            $pnp_db{$1} = $2;
        }
    }
    close $fh;
}

sub _decode_vendor {
   my $raw = shift;
   my $id = unpack("n", $raw);

   return join "",
       chr(64+(($id>>10)&31)),
       chr(64+(($id>>5)&31)),       
       chr(64+(($id)&31));
}

sub _parse_edid {
    my $file = shift;

    open my $fh,'<',$file or return;
    binmode $fh;
    read $fh, my $edid, 128;
    close $fh;

    return unless length($edid)==128;

    my $vendor = _decode_vendor(substr($edid,8,2));
    my $product = sprintf("%04x",unpack("v",substr($edid,10,2)));
    my $serial  = unpack("V",substr($edid,12,4));

    my $hsize = unpack("C",substr($edid,21,1));
    my $vsize = unpack("C",substr($edid,22,1));

    my $size = 0;
    if ($hsize && $vsize) {
        my $diag_cm = sqrt($hsize*$hsize + $vsize*$vsize);
        $size = sprintf("%.1f",$diag_cm/2.54);
    }

    my $hash = sha256_hex($vendor.$product.$serial);

    return {
        VENDOR      => $vendor,
        VENDOR_NAME => $pnp_db{$vendor} // "Unknown",
        PRODUCT_ID  => $product,
        SERIAL      => $serial // "Unknown",
        SIZE_INCH   => $size,
        HASH        => $hash,
    };
}       

sub _get_resolution {
    my %res;
    my $out = `xrandr 2>/dev/null`;
    foreach my $line (split /\n/,$out) {
        if ($line =~ /^(\S+)\sconnected\s.*?(\d+x\d+)/) {
            $res{$1}=$2;
        }
    }
    return \%res;
}

sub run {
   my $params = shift;
   my $common = $params->{common};
   my $logger = $params->{logger};

   _load_pnp_ids();

   my $drm="/sys/class/drm";
   return unless -d $drm;

   my $resolution=_get_resolution();

   opendir(my $dh,$drm);
   while(my $entry=readdir($dh)){
        next unless $entry =~ /^card\d+-/;
        my $edid="$drm/$entry/edid";
        next unless -f $edid;

        my $info=_parse_edid($edid);
        next unless $info;

        my $en = $entry ;
        $en =~ s/^card\d+-//g;
        my $res=$resolution->{$en} // "unknown";

        $common->addMonitor({
            CONNECTOR    => $entry,
            VENDOR       => $info->{VENDOR},
            MANUFACTURER => $info->{VENDOR_NAME},
            PRODUCT_ID   => $info->{PRODUCT_ID},
            SERIAL       => $info->{SERIAL},
            SIZE         => $info->{SIZE_INCH},
            RESOLUTION   => $res,
            HASH         => $info->{HASH} 
        });
    }
    closedir($dh);
}

1;     
