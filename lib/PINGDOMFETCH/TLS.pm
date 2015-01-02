package PINGDOMFETCH::TLS;

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
    $self->{is_critical} = 0;

    return $self;
}

sub acc {
    my ($self) = @_;

    my $config       = $self->{config};
    my $is_in_future = $config->bool('interval_is_in_future');

    my $count      = 0;
    my $tls_result = PINGDOMFETCH::Result->new(
        config       => $config,
        totaldown    => 0,
        totalup      => 0,
        totalunknown => 0,
        avgresponse  => 0,
        remaining    => 0,
    );
    $tls_result->{remaining} = 0 if $is_in_future;

    my $acc = sub {
        my ( $service, $result ) = @_;

        $count++;
        my $weight =
          exists $service->{opts}{weight}
          ? $service->{opts}{weight}
          : 1;

        $tls_result->{$_} += $result->{$_} * $weight
          for qw(totaldown totalup totalunknown);

        $tls_result->{$_} += $result->{$_} for qw(avgresponse);

        $tls_result->{remaining} += $result->{remaining} * $weight
          if $is_in_future;
    };

    if ( exists $self->{services} ) {
        $self->{services}{$_}->acc($acc) for keys %{ $self->{services} };
    }

    if ( $count > 0 ) {
        $tls_result->{avgresponse} /= $count;
        $tls_result->compute();
        $self->{result} = $tls_result;
    }

    $self->{is_critical} = 1
      if $self->{result}{avail_perc} <
          $config->get('critical.if.avail.is.less');

    return undef;
}

sub print {
    my ($self) = @_;

    my $config       = $self->{config};
    my $is_in_future = $config->bool('interval_is_in_future');
    my $notify       = $config->{notify};

    my $str = do {
        if ($is_in_future) {
            sprintf(
"TLS: %03.3f%%; %s (Best: %03.3f%%; Worst: %03.3f%%; Avgresponse: %dms)",
                $self->{result}{avail_perc},
                $self->{name},
                $self->{result}{possible_avail_perc_best},
                $self->{result}{possible_avail_perc_worst},
                $self->{result}{avgresponse}
            );
        }
        else {
            sprintf(
                "TLS: %03.3f%%; %s (Avgresponse: %dms)",
                $self->{result}{avail_perc},
                $self->{name}, $self->{result}{avgresponse}
            );
        }
    };

    if ( $self->{result}{avail_perc} <
        $config->get('critical.if.avail.is.less') )
    {
        $self->critical( $str, $notify );

    }
    elsif (
        $self->{result}{avail_perc} < $config->get('warning.if.avail.is.less') )
    {
        $self->warning( $str, $notify );

    }
    else {
        $self->info( $str, $notify );
    }

    if ( exists $self->{services} ) {
        $self->inc();

        my @sorted_data =
          sort { $b->{result}{avail_perc} <=> $a->{result}{avail_perc} }
          values %{ $self->{services} };
        @sorted_data = reverse @sorted_data
          if $config->bool('arg.sort-reverse');

        $_->print() for @sorted_data;
        $self->dec();
    }

    return undef;
}

sub print_full {
    my ($self) = @_;

    my $config = $self->{config};

    $self->info("TLS $self->{name}");
    $self->inc();

    if ( exists $self->{result} ) {
        $self->{result}->print_full();
    }

    $self->info("$_: $self->{$_}")
      for sort grep { not ref $self->{$_} and $_ ne 'name' } keys %$self;

    if ( exists $self->{services} ) {
        $self->inc();
        while ( my ( $k, $v ) = each %{ $self->{services} } ) {
            $v->print_full();
        }
        $self->dec();

    }
    else {
        $self->warning("No services for this TLS");
    }

    $self->dec();

    return undef;
}

1;

