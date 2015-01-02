package PINGDOMFETCH::Service;

use strict;
use warnings;

use PINGDOMFETCH::Config;
use PINGDOMFETCH::Display;
use PINGDOMFETCH::Result;
use PINGDOMFETCH::Utils;

our @ISA = ('PINGDOMFETCH::Display');

sub new {
    my ( $class, %vals ) = @_;

    my $self = bless \%vals, $class;

    return $self;
}

sub acc {
    my ( $self, $acc ) = @_;

    $self->{result}->acc( $self, $acc ) if exists $self->{result};

    return undef;
}

sub print {
    my ($self) = @_;

    my $config       = $self->{config};
    my $is_in_future = $config->bool('interval_is_in_future');
    my $notify       = $config->{notify};

    my $avail_perc = do {
        if ( exists $self->{result} ) {
        }
        else {
            '';
        }
    };
    my $str = do {
        if ($is_in_future) {
            sprintf(
"Service: %03.3f%%; %s (Best: %03.3f%%; Worst: %03.3f%%; Avgresponse: %dms)",
                $self->{result}{avail_perc},
                $self->{name},
                $self->{result}{possible_avail_perc_best},
                $self->{result}{possible_avail_perc_worst},
                $self->{result}{avgresponse}
            );
        }
        else {
            sprintf(
                "Service: %03.3f%%; %s (Avgresponse: %dms)",
                $self->{result}{avail_perc},
                $self->{name}, $self->{result}{avgresponse}
            );
        }
    };

    my @opts;
    my $opts     = $self->{opts};
    my $opts_str = $config->get_opts_str($opts);

    my $warning_less =
      exists $self->{opts}{warning}
      ? $self->{opts}{warning}
      : $config->get('warning.if.avail.is.less');

    my $critical_less =
      exists $self->{opts}{critical}
      ? $self->{opts}{critical}
      : $config->get('critical.if.avail.is.less');

    if ( $self->{result}{avail_perc} < $critical_less ) {
        $self->critical( $str . $opts_str, $notify );
    }
    elsif ( $self->{result}{avail_perc} < $warning_less ) {
        $self->warning( $str . $opts_str, $notify );
    }
    else {
        $self->info( $str . $opts_str, $notify );
    }

    return undef;
}

sub print_full {
    my ($self) = @_;

    my $config = $self->{config};

    $self->info("Service: $self->{name}");

    $self->inc();
    $self->{result}->print_full() if exists $self->{result};
    $self->dec();

    return undef;
}

1;

