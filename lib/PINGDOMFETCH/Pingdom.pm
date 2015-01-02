package PINGDOMFETCH::Pingdom;

use strict;
use warnings;

use JSON;
use Data::Dumper;
use IO::CaptureOutput qw(capture_exec);

use PINGDOMFETCH::Display;
use PINGDOMFETCH::Config;
use PINGDOMFETCH::Result;
use PINGDOMFETCH::Service;
use PINGDOMFETCH::DateHelper;
use PINGDOMFETCH::Utils;

our @ISA = ('PINGDOMFETCH::Display');

sub new {
    my ( $class, $config ) = @_;

    my $app_key  = $config->get('pingdom.api.app.key');
    my $host     = $config->get('pingdom.api.host');
    my $port     = $config->get('pingdom.api.port');
    my $protocol = $config->get('pingdom.api.protocol');

    my $json = JSON->new()->allow_nonref();

    #$ua->credentials( "$host:$port", $realm, $username, $password );

    my $headers = {
        'App-key'    => $app_key,
        'User-Agent' => 'pingdomfetch',
    };

    my $url_base = "$protocol://$host:$port";

    my $self = bless {
        config   => $config,
        json     => $json,
        url_base => $url_base,
        headers  => $headers,
    }, $class;

    return $self;
}

sub safe_get {
    my ( $self, $j, @keys ) = @_;

    my $pos = $j;

    for (@keys) {
        if ( exists $pos->{$_} ) {
            $pos = $pos->{$_};

        }
        else {
            local $" = '.';
            $self->error(
                "Could not get key '@keys' from JSON result: " . Dumper($j) );
        }
    }

    return $pos;
}

sub fetch {
    my ( $self, $url ) = @_;

    my $config  = $self->{config};
    my $json    = $self->{json};
    my $headers = $self->{headers};

    my $curl   = $config->get('curl.path');
    my $retry  = $config->get('pingdom.api.failed.retry.after');
    my $giveup = $config->get('pingdom.api.failed.giveup.after');

    my $password = $config->get('pingdom.auth.password');
    my $username = $config->get('pingdom.auth.username');

    my $proxy = '';
    $proxy = ' -p -x ' . $config->get('pingdom.proxy.address')
      if $config->bool('pingdom.proxy.use');

    my $cmd = "$curl '$url'$proxy --user '$username:$password'";
    $cmd .= " --header '$_: $headers->{$_}'" for keys %$headers;

    my ( $stdout, $stderr, $success, $exit_code );

    for ( my $i = 0 ; $i < $giveup ; ++$i ) {
        $self->verbose("Using URL $url");
        $self->verbose("$cmd");
        ( $stdout, $stderr, $success, $exit_code ) = capture_exec($cmd);

        if ( $exit_code == 0 ) {
            last;

        }
        else {
            $self->warning( "Pingdom: stdout=" . $stdout );
            $self->warning( "Pingdom: stderr=" . $stderr );
            $self->warning( "Pingdom: success=" . $success );
            $self->warning( "Pingdom: exit_code=" . $exit_code );
            $self->warning("Retrying $url after $retry seconds");
            sleep $retry;
        }
    }

    return $json->decode($stdout);
}

sub fetch_avail_json {
    my ( $self, $service, $from, $to ) = @_;

    my $config   = $self->{config};
    my $checkid  = $service->{checkid};
    my $url_base = $self->{url_base};
    my $action   = $config->get('pingdom.api.average.action');
    my $url = "$url_base/$action/$checkid?includeuptime=true&from=$from&to=$to";

    $self->verbose(
"Fetching availability for service $service->{name} (checkid $checkid) from Pingdom"
    );

    return $self->fetch($url);
}

sub fetch_avail_result {
    my ( $self, $service ) = @_;

    my $config  = $self->{config};
    my $dh_from = $config->{dh_from};
    my $dh_to   = $config->{dh_to};

    if ( $dh_from->is_in_future() ) {
        $self->verbose("'from' is in future");
        $dh_from = PINGDOMFETCH::DateHelper->new( $self->{config} );
    }

    if ( $dh_to->is_in_future() ) {
        $self->verbose("'to' is in future");
        $dh_to = PINGDOMFETCH::DateHelper->new( $self->{config} );
    }

    my $j =
      $self->fetch_avail_json( $service, $dh_from->time(), $dh_to->time() );

    return PINGDOMFETCH::Result->new(
        config       => $config,
        service      => $service,
        totalup      => $self->safe_get( $j, qw(summary status totalup) ),
        totalup      => $self->safe_get( $j, qw(summary status totalup) ),
        totaldown    => $self->safe_get( $j, qw(summary status totaldown) ),
        totalunknown => $self->safe_get( $j, qw(summary status totalunknown) ),
        avgresponse =>
          $self->safe_get( $j, qw(summary responsetime avgresponse) ),
    );
}

sub fetch_all_checks_json {
    my ($self) = @_;

    my $config = $self->{config};

    my $url_base = $self->{url_base};
    my $action   = $config->get('pingdom.api.all.checks.action');

    my $url = "$url_base/$action";

    $self->verbose("Fetching all checks from Pingdom");

    return $self->fetch($url);
}

sub fetch_all_subscriptions_json {
    my ($self) = @_;

    my $config = $self->{config};

    my $url_base = $self->{url_base};
    my $action   = $config->get('pingdom.api.all.report.subscriptions');

    my $url = "$url_base/$action";

    $self->verbose("Fetching all report subscriptions from Pingdom");

    return $self->fetch($url);
}

1;
