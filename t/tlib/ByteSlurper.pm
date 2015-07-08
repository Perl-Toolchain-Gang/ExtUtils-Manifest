package ByteSlurper;

# "Raw" was too vague, especially seeing its not :raw.
# ":unix" being how we get "Raw" is too confusing.
# ITS BYTES.

use strict;
use warnings;

use Carp 'croak';
use Exporter;
*import = \&Exporter::import;

our @EXPORT_OK = qw/read_bytes write_bytes/;

sub read_bytes {
    my ($filename) = @_;
    open my $fh, "<:unix", $filename or croak "Couldn't open $filename: $!";
    return do { local $/; <$fh> };
}

sub write_bytes {
    my ( $filename, undef ) = @_;
    open my $fh, ">:unix", $filename or croak "Couldn't open $filename: $!";
    print $fh $_[1] or croak "Couldn't write to $filename: $!";
    close $fh or croak "Couldn't write to $filename: $!";
    return;
}

1;
