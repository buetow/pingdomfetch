package PINGDOMFETCH::Config;

use strict;
use warnings;

use IO::File;

use PINGDOMFETCH::Display;
use PINGDOMFETCH::Notify;
use PINGDOMFETCH::Service;
use PINGDOMFETCH::TLS;
use PINGDOMFETCH::Utils;

our @ISA = ('PINGDOMFETCH::Display');

sub new {
    my ( $class, $opts ) = @_;

    my %vals = map {
        my $k = $_;
        $k =~ s/_/\./g;
        "arg.$k" => $opts->{$_}{val};

    } keys %$opts;

    my $self = bless \%vals, $class;

    $self->SUPER::init();

    $self->read_config('/etc/pingdomfetch.conf');
    $self->read_config('pingdomfetch.conf');
    $self->read_config($_) for sort glob("/etc/pingdomfetch.d/*.conf");

    $self->read_config("$ENV{HOME}/.pingdomfetch.conf");
    $self->read_config($_) for sort glob("$ENV{HOME}/.pingdomfetch.d/*.conf");

    $self->read_config( $self->{'arg.config'} );

    unless ( exists $self->{config_was_read} ) {
        $self->warning("No config file found. Use --verbose or --help");
    }

    $self->{notify} = PINGDOMFETCH::Notify->new( config => $self );
    $self->{has_warnings} = 0;

    return $self;
}

sub read_config {
    my ( $self, $config_file ) = @_;

    return undef unless -f $config_file;

    my $fh = new IO::File( $config_file, 'r' );
    $self->error("Could not open file $config_file") unless defined $fh;

    $self->verbose("Reading config $config_file");

    my $section = undef;
    my $tls = exists $self->{tls} && ref $self->{tls} ? $self->{tls} : {};

    while ( my $line = $fh->getline() ) {

        # Ignore comments
        $line =~ s/(.*);.*/$1/;

        if ( $line =~ /^\[(.*)\]/ ) {
            $section = $1;
            next;
        }

        next unless defined $section;

        if (   $section eq 'pingdom'
            or $section eq 'misc'
            or $section eq 'notify' )
        {

            # Parse only matching lines
            if ( $line =~ /^(.*)=(.*)/ ) {
                my ( $key, $val ) = ( lc trim $1, trim $2);
                $self->verbose("Reading conf value $key");
                $self->set( $key, $val );
            }

        }
        elsif ( $section =~ /^tls\.(.*)/ ) {
            my ($tlsname) = ($1);

            next if $line !~ /\w/;

            my ( $servicename, $opts ) = split '=', trim($line);

            $servicename = lc trim($servicename);
            $opts = trim($opts) if defined $opts;

            $tls->{$tlsname} = PINGDOMFETCH::TLS->new(
                name     => $tlsname,
                config   => $self,
                services => {},

            ) unless exists $tls->{$tlsname};

            my %opts;

            if ( defined $opts ) {
                for ( split ',', $opts ) {
                    my ( $k, $v ) = split ':';
                    $opts{$k} = $v;
                }
            }

            $self->verbose("TLS $tlsname includes service $servicename");
            $tls->{$tlsname}{services}{$servicename} = { opts => \%opts };
        }
    }

    $fh->close();
    $self->{tls} = $tls;

    $self->{config_was_read} = 1;

    return undef;
}

sub read_services {
    my ( $self, $pingdom ) = @_;

    $self->verbose('Reading all the services');

    my $j = $pingdom->fetch_all_checks_json();
    my $checks = $pingdom->safe_get( $j, 'checks' );

    my %services = map {
        my $name = lc $pingdom->safe_get( $_, 'name' );
        my $checkid = $pingdom->safe_get( $_, 'id' );

        $self->verbose("$name has check id $checkid");

        $name => PINGDOMFETCH::Service->new(
            config     => $self,
            name       => $name,
            checkid    => $checkid,
            resolution => $pingdom->safe_get( $_, 'resolution' ),
        );

    } @$checks;

    $self->{services} = \%services;

    return undef;
}

sub read_tls {
    my ($self) = @_;

    my $services = $self->{services};
    my $tls      = $self->{tls};

    for my $tlsname ( keys %$tls ) {
        my $tlsservices     = $tls->{$tlsname}{services};
        my @tlsservicenames = keys %$tlsservices;

        $self->verbose("Validating services for TLS $tlsname");

        my @delete;

        for ( sort @tlsservicenames ) {
            if ( exists $services->{$_} ) {
                $services->{$_}{opts} = $tlsservices->{$_}{opts};
                $tlsservices->{$_} = $services->{$_};

            }
            else {
                $self->warning(
                    "Service $_ not configured in Pingdom, ignoring it");
                push @delete, $_;
            }
        }

        delete $tlsservices->{$_} for @delete;
    }

    return undef;
}

sub get {
    my ( $self, $key ) = @_;
    $key = lc $key;

    $self->{$key} //= do {
        my $key = uc $key;
        $key =~ s/\./_/g;

        exists $ENV{$key} ? $ENV{$key} : undef;
    };

    if (   not exists $self->{$key}
        or not defined $self->{$key}
        or $self->{$key} eq '' )
    {
        $self->error("$key not configured");
    }

    $self->verbose("Getting config value $key=$self->{$key}");
    return $self->{$key};
}

sub has {
    my ( $self, $key ) = @_;
    $key = lc $key;

    $self->{$key} //= do {
        my $key = uc $key;
        $key =~ s/\./_/g;

        exists $ENV{$key} ? $ENV{$key} : undef;
    };

    if (   not exists $self->{$key}
        or not defined $self->{$key}
        or $self->{$key} eq '' )
    {
        return 0;
    }

    return 1;
}

sub bool {
    my ( $self, $key ) = @_;

    my $val = $self->get($key);

    return $val != 0;
}

sub array {
    my ( $self, $key ) = @_;

    my $val = $self->get($key);

    return map { trim $_ } split ',', $val;
}

sub set {
    my ( $self, $key, $val ) = @_;
    $key = lc $key;

    $self->warning("$key already configured, overwriting it with its new value")
      if exists $self->{$key};

    return $self->{$key} = $val;
}

sub get_opts_str {
    my ( $self, $opts ) = @_;

    return '' unless defined $opts;

    my $opts_str = '';

    if (%$opts) {
        $opts_str = ' [';
        $opts_str .= join ',', map { "$_:$opts->{$_}" }
          sort keys %$opts;
        $opts_str .= ']';
    }

    return $opts_str;
}

sub print_services {
    my ($self) = @_;

    for ( sort keys %{ $self->{services} } ) {
        my $opts_str = $self->get_opts_str( $self->{services}{$_}{opts} );
        $self->info( $_ . $opts_str );
    }

    return 0;
}

sub print_tls {
    my ($self) = @_;

    for my $k ( sort keys %{ $self->{tls} } ) {
        my $v = $self->{tls}{$k};
        $self->info($k);
        $self->inc();
        for ( sort keys %{ $v->{services} } ) {
            my $opts_str = $self->get_opts_str( $v->{services}{$_}{opts} );
            $self->info( $_ . $opts_str );
        }
        $self->dec();
    }

    return 0;
}

1;
