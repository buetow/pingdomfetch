package PINGDOMFETCH::DateHelper;

use strict;
use warnings;

use Date::Format;
use Time::ParseDate;

use PINGDOMFETCH::Config;
use PINGDOMFETCH::Display;
use PINGDOMFETCH::Utils;

our @ISA = ('PINGDOMFETCH::Display');

use overload '""' => sub {
    my ($self) = @_;
    $self->full_str();
};

sub new ($;$) {
    my ( $class, $config, $time ) = @_;

    my $self = bless { config => $config }, $class;

    $self->time($time);

    return $self;
}

sub time {
    my ( $self, $time ) = @_;

    my $config = $self->{config};

    $time = $self->{time} if not defined $time or $time eq '';

    if ( not defined $time or $time eq '' ) {
        $time //= time();
        return $self->{time} = $time;

    }
    elsif ( $time !~ /^\d+$/ ) {
        my $parsed = parsedate($time);
        $self->error("Can't parse time '$time'") unless defined $parsed;
        $time = $parsed;
    }

    return $self->{time} = $time;
}

sub flatten {
    my ( $self, $flatten ) = @_;

    if ( $flatten eq 'bod' ) {
        return $self->begin_of_day();
    }
    elsif ( $flatten eq 'eod' ) {
        return $self->end_of_day();
    }
    elsif ( $flatten eq 'boh' ) {
        return $self->begin_of_hour();
    }
    elsif ( $flatten eq 'eoh' ) {
        return $self->end_of_hour();
    }
    else {
        $self->error("Can't parse flatten method '$flatten'");
    }
}

sub localtime {
    my ( $self, $time ) = @_;

    return localtime( $self->time($time) );
}

sub prev_day {
    my ( $self, $time ) = @_;

    return $self->time( $self->time($time) - 86400 );
}

sub next_day {
    my ( $self, $time ) = @_;

    return $self->time( $self->time($time) + 86400 );
}

sub begin_of_day {
    my ( $self, $time ) = @_;

    my @localtime = $self->localtime($time);
    my ( $sec, $min, $hour, @rest ) = @localtime;

    return $self->time( $self->time() - $sec - 60 * ( $min + 60 * $hour ) );
}

sub end_of_day {
    my ( $self, $time ) = @_;

    my @localtime = $self->localtime($time);
    my ( $sec, $min, $hour, @rest ) = @localtime;

    return $self->time( $self->begin_of_day() + 86399 );
}

sub begin_of_hour {
    my ( $self, $time ) = @_;

    my @localtime = $self->localtime($time);
    my ( $sec, $min, $hour, @rest ) = @localtime;

    return $self->time( $self->time() - $sec - 60 * $min );
}

sub end_of_hour {
    my ( $self, $time ) = @_;

    return $self->time( $self->begin_of_hour() + 59 * ( 1 + 60 ) );
}

sub is_a_day {
    my ($self) = @_;

    return $self->time() == 86400;
}

sub is_begin_of_a_day {
    my ($self) = @_;

    my @localtime = $self->localtime( $self->time() );
    my ( $sec, $min, $hour, @rest ) = @localtime;

    return $sec == 0 and $min == 0 and $hour == 0;
}

sub is_in_future {
    my ($self) = @_;

    my $dh = PINGDOMFETCH::DateHelper->new( $self->{config} );

    return $self->time() > $dh->time() ? 1 : 0;
}

sub days_until {
    my ( $self, $dh ) = @_;

    return ( $dh->time() - $self->time() ) / 86400;
}

sub day_str {
    my ( $self, $time ) = @_;

    my @localtime = $self->localtime($time);

    #return strftime( "%D", @localtime );
    return strftime( "%d.%m.%Y", @localtime );
}

sub full_str {
    my ( $self, $time ) = @_;

    my @localtime = $self->localtime($time);

    #return strftime( "%c", @localtime );
    return strftime( "%d.%m.%Y %H:%M:%S", @localtime );
}

sub print {
    my ( $self, $time ) = @_;

    $self->time($time);

    say $self->full_str();

    return undef;
}

1;
