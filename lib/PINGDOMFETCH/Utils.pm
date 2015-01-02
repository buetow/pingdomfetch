package PINGDOMFETCH::Utils;

use strict;
use warnings;

use Data::Dumper;
use Exporter;

use base 'Exporter';

our @EXPORT = qw (
  d
  dumper
  get_version
  get_version_full
  newline
  notnull
  null
  remove_spaces
  say
  sum
  trim
);

sub say (@) { print "$_\n" for @_; return undef }
sub newline () { say ''; return undef }
sub sum (@) { my $sum = 0; $sum += $_ for @_; return $sum }
sub null ($)    { defined $_[0] ? $_[0] : 0 }
sub notnull ($) { $_[0] != 0    ? $_[0] : 1 }
sub dumper (@)  { die Dumper @_ }
sub d (@)       { dumper @_ }

sub trim ($) {
    my $trimit = shift;

    $trimit =~ s/^[\s\t]+//;
    $trimit =~ s/[\s\t]+$//;

    return $trimit;
}

sub remove_spaces ($) {
    my $str = shift;

    $str =~ s/[\s\t]//g;

    return $str;
}

sub get_version () {
    my $versionfile = do {
        if ( -f '.version' ) {
            '.version';
        }
        else {
            '/usr/share/pingdomfetch/version';
        }
    };

    open my $fh, $versionfile or error("$!: $versionfile");
    my $version = <$fh>;
    close $fh;

    chomp $version;
    return $version;
}

sub get_version_full () {
    return "This is Pingdomfetch Version " . get_version() . "\n";
}

1;
