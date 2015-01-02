package PINGDOMFETCH::Result;

use strict;
use warnings;

use PINGDOMFETCH::Config;
use PINGDOMFETCH::DateHelper;
use PINGDOMFETCH::Display;
use PINGDOMFETCH::Utils;

our @ISA = ('PINGDOMFETCH::Display');

sub new {
    my ( $class, %vals ) = @_;

    my $self = bless \%vals, $class;

    $self->compute();

    return $self;
}

sub acc {
    my ( $self, $service, $acc ) = @_;

    $acc->( $service, $self );

    return undef;
}

sub compute {
    my ($self) = @_;

    my $config = $self->{config};

    my ( $up, $down, $total ) = $self->compute_up_down();
    $self->{avail_perc} = $self->compute_avail_perc( $up, $down, $total );

    if ( $config->bool('interval_is_in_future') ) {
        my $remaining = do {

            # It's a Service result and not a TLS
            if ( exists $self->{service} ) {

                # Total seconds in the current interval
                my $seconds =
                  $config->{dh_to}->time() - $config->{dh_from}->time();
                $self->{remaining} = $seconds - $total;

            }
            else {

                # It's a TLS result
                $self->{remaining};
            }
        };

        $self->{possible_avail_perc_best} =
          $self->compute_avail_perc( $up + $remaining, $down );

        $self->{possible_avail_perc_worst} =
          $self->compute_avail_perc( $up, $down + $remaining );
    }

    return undef;
}

sub compute_up_down {
    my ( $self, $totalup, $totalunknown, $totaldown ) = @_;

    my $config  = $self->{config};
    my $unknown = $config->get('interpret.unknown.status.as.up');

    $totalup      = $self->{totalup}      unless defined $totalup;
    $totaldown    = $self->{totaldown}    unless defined $totaldown;
    $totalunknown = $self->{totalunknown} unless defined $totalunknown;

    my $total = $totalup + $totaldown + $totalunknown;

    return $unknown =~ /true/i
      ? ( $totalup + $totalunknown, $totaldown, $total )
      : ( $totalup, $totaldown + $totalunknown, $total );
}

sub compute_avail_perc {
    my ( $self, $up, $down ) = @_;

    my $config = $self->{config};
    my $zero   = $config->get('interpret.zero.results.as.up');

    my $total = $up + $down;

    if ( $total > 0 ) {
        return 100 * $up / $total;
    }
    else {
        return $zero =~ /true/i ? 100 : 0;
    }
}

sub print {
    my ($self) = @_;

    $self->print_full();

    return undef;
}

sub print_full {
    my ($self) = @_;

    my $config = $self->{config};

    $self->info("$_: $self->{$_}")
      for sort grep { not ref $self->{$_} } keys %$self;

    return undef;
}

1;
