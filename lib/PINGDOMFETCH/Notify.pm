package PINGDOMFETCH::Notify;

use strict;
use warnings;

use PINGDOMFETCH::Config;
use PINGDOMFETCH::DateHelper;
use PINGDOMFETCH::Display;
use PINGDOMFETCH::Utils;

use MIME::Lite;

our @ISA = ('PINGDOMFETCH::Display');

sub new {
    my ( $class, %vals ) = @_;

    my $self = bless \%vals, $class;

    my $config = $self->{config};

    $self->{message}   = [];
    $self->{warnings}  = 0;
    $self->{criticals} = 0;

    return $self;
}

sub message_push {
    my ( $self, $message ) = @_;

    push @{ $self->{message} }, $message;

    return undef;
}

sub message_unshift {
    my ( $self, $message ) = @_;

    my $config = $self->{config};
    unshift @{ $self->{message} }, $message;

    return undef;
}

sub has_messages {
    my ($self) = @_;

    return @{ $self->{message} } > 0 ? 1 : 0;
}

sub has_warnings {
    my ($self) = @_;

    return $self->{warnings} > 0 ? 1 : 0;
}

sub has_criticals {
    my ($self) = @_;

    return $self->{criticals} > 0 ? 1 : 0;
}

sub info_notification_send {
    my ($self) = @_;

    my $config = $self->{config};
    $self->notification_send_to( $config->array('notify.info.email.to') );

    return undef;
}

sub notification_send {
    my ($self) = @_;

    my $config = $self->{config};
    $self->notification_send_to( $config->array('notify.email.to') );

    return undef;
}

sub notification_send_to {
    my ( $self, @email_to ) = @_;

    return if !$self->has_messages();

    my $config        = $self->{config};
    my $from          = $config->get('notify.email.sender');
    my $warning_less  = $config->get('warning.if.avail.is.less');
    my $critical_less = $config->get('critical.if.avail.is.less');

    my ( $dh_from, $dh_to ) = ( $config->{'dh_from'}, $config->{'dh_to'} );
    my $message = join '', @{ $self->{message} };

    my $subject = do {
        if ( $self->has_criticals() ) {
            '!! ';
        }
        elsif ( $self->has_warnings() ) {
            '!  ';
        }
        else {
            '   ';
        }
    };

    $subject .= 'Availability stats for ';

    if (    $dh_from->is_begin_of_a_day()
        and $dh_to->is_begin_of_a_day()
        and 1 == $dh_from->days_until($dh_to) )
    {
        $subject .= $dh_from->day_str();
    }
    else {
        $subject .= "'$dh_from' - '$dh_to'";
    }

    $message .= "Legend:\n";
    $message .=
"'!' means: TLS or Service Availability is less than $warning_less% (Exception: Threshold is non-standard)\n";
    $message .= "'!!' means: TLS Availability is less than $critical_less%\n\n";
    $message .=
"Response times are not reasonable (collected from all over the world)!\n";

    $message .= "\n" . get_version_full();

    unless ( $config->bool('arg.notify-dummy') ) {
        $self->send_mail( $from, $_, $subject, $message ) for @email_to;

    }
    else {
        $self->info("Dummy-Email to stdout");

        say $subject;
        say "";
        say $message;
    }

    $self->{messages} = [];

    return undef;
}

sub send_mail {
    my ( $self, $from, $to, $subject, $message ) = @_;

    my $email = MIME::Lite->new(
        From    => $from,
        To      => $to,
        Subject => $subject,
        Type    => 'TEXT',
        Data    => $message,
    );

    $self->info("Sending email '$subject' to '$to'");
    $email->send();

    return undef;
}

1;

