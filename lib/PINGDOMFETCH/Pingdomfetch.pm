package PINGDOMFETCH::Pingdomfetch;

use strict;
use warnings;

use PINGDOMFETCH::Config;
use PINGDOMFETCH::DateHelper;
use PINGDOMFETCH::Display;
use PINGDOMFETCH::Notify;
use PINGDOMFETCH::Pingdom;
use PINGDOMFETCH::Utils;

our @ISA = ('PINGDOMFETCH::Display');

sub new {
    my ( $class, $opts ) = @_;

    my $config  = PINGDOMFETCH::Config->new($opts);
    my $pingdom = PINGDOMFETCH::Pingdom->new($config);

    my $self = bless {
        config       => $config,
        pingdom      => $pingdom,
        dots_counter => 0,
    }, $class;

    $self->init_from_to_interval();

    return $self;
}

sub init_from_to_interval {
    my ($self) = @_;

    my $config = $self->{config};

    # Yeah, Hash Slices are hellworks!
    my ( $from, $to ) = @{$config}{qw(arg.from arg.to)};

    my $dh_from = $config->{dh_from} =
      PINGDOMFETCH::DateHelper->new( $config, $from );
    my $dh_to = $config->{dh_to} =
      PINGDOMFETCH::DateHelper->new( $config, $to );

    $dh_from->begin_of_day() if $from eq '';

    # Handle the --flatten switcht
    my $flatten = $config->{'arg.flatten'};
    my ( $flatten_from, $flatten_to ) = split ':', $flatten;

    if ( defined $flatten_from ) {
        $dh_from->flatten($flatten_from)
          if $flatten_from ne '';

        $dh_to->flatten($flatten_to)
          if defined $flatten_to and $flatten_to ne '';
    }

    $self->error(
"Interval '$dh_from' - '$dh_to' is negative or zero. 'from' must be < 'to'."
    ) if $dh_from->time() >= $dh_to->time();

    $config->{interval_is_in_future} = $dh_to->is_in_future();

    $self->{dh_from} = $dh_from;
    $self->{dh_to}   = $dh_to;

    return undef;
}

sub get_checkid_avail {
    my ( $self, $checkid ) = @_;

    my $config   = $self->{config};
    my $services = $config->{services};

    while ( my ( $k, $v ) = each %$services ) {
        if ( $v->{checkid} eq $checkid ) {
            $self->verbose("Checkid $checkid belongs to service $k");
            $self->get_all_services_avail( { $k => $v } );

            return ($v);
        }
    }

    $self->error("No such service with checkid '$checkid'");

    return ();
}

sub get_service_avail {
    my ( $self, $servicename ) = @_;

    my $config   = $self->{config};
    my $services = $config->{services};

    if ( exists $services->{$servicename} ) {
        my $service = $services->{$servicename};
        $self->get_all_services_avail( { $servicename => $service } );

        return $service;
    }

    $self->error("No such service '$servicename'");

    return ();
}

sub get_tls_avail {
    my ( $self, $tlsname ) = @_;

    my $config = $self->{config};

    my @results;

    if ( ref $config->{tls}{$tlsname} ) {
        my $tls      = $config->{tls}{$tlsname};
        my $services = $tls->{services};

        $self->get_all_services_avail($services);
        $tls->acc();

        return ($tls);

    }
    else {
        $self->error("No such TLS '$tlsname'");
    }

    return ();
}

sub get_all_services_avail {
    my ( $self, $services ) = @_;

    my $pingdom = $self->{pingdom};
    my $config  = $self->{config};

    my @return;

    while ( my ( $k, $v ) = each %$services ) {
        unless ( $config->is_verbose() ) {
            $self->{dots_counter}++;

            if ( $self->{dots_counter} == 3 ) {
                print '...';

            }
            elsif ( $self->{dots_counter} > 3 ) {
                print '.';
            }
        }
        $v->{result} = $pingdom->fetch_avail_result($v);
        push @return, $v;
    }

    return @return;
}

sub run {
    my ($self) = @_;
    my $retval = 0;

    my $config  = $self->{config};
    my $pingdom = $self->{pingdom};

    $config->read_services($pingdom);
    $config->read_tls();

    return $config->print_services() if $config->{'arg.list-services'};

    return $config->print_tls() if $config->{'arg.list-tls'};

    $self->info(
        "Fetching stats of interval '$self->{dh_from}' - '$self->{dh_to}'");

    my @data;

    push @data, $self->get_checkid_avail( $config->{'arg.checkid'} )
      if $config->{'arg.checkid'} ne '';

    push @data, $self->get_service_avail( $config->{'arg.service'} )
      if $config->{'arg.service'} ne '';

    if ( $config->{'arg.tls'} ne '' ) {
        if ( $config->{'arg.tls'} =~ /,/ ) {
            push @data, $self->get_tls_avail($_)
              for split ',', $config->{'arg.tls'};
        }
        else {
            push @data, $self->get_tls_avail( $config->{'arg.tls'} );
        }
    }

    push @data, $self->get_all_services_avail( $config->{services} )
      if $config->{'arg.all-services'};

    if ( $config->{'arg.all-tls'} ) {
        push @data, $self->get_tls_avail($_) for sort keys %{ $config->{tls} };
    }

    if (@data) {
        my @sorted_data =
          sort { $b->{result}{avail_perc} <=> $a->{result}{avail_perc} } @data;
        @sorted_data = reverse @sorted_data
          if $config->bool('arg.sort-reverse');

        if ( $self->is_verbose() ) {
            $self->error("--notify* can not be used together with --verbose")
              if $config->bool('arg.notify-info')
                  or $config->bool('arg.notify');

            for (@sorted_data) {
                $_->print_full();
                $self->nl();
            }

        }
        else {
            print "\n" if $self->{dots_counter} > 2;

            my $notify = $config->{notify};

            for (@sorted_data) {
                $_->print();
                $self->nl($notify);
            }

            $notify->info_notification_send()
              if $config->bool('arg.notify-info');

            $notify->notification_send()
              if $config->bool('arg.notify')
                  and ( $notify->has_warnings(), or $notify->has_criticals() );
        }
    }
    else {
        $self->warning(
            "No results found. Use --all-tls for all TLS or --help for help!");
    }

    return 0;
}

1;
