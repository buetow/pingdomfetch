package PINGDOMFETCH::Display;

use strict;
use warnings;

use Data::Dumper;

use PINGDOMFETCH::Config;
use PINGDOMFETCH::Utils;

our $INDENT  = 0;
our $VERBOSE = 0;

use overload
  '""' => sub { shift->indents(); },
  '++' => sub { shift->inc(); },
  '--' => sub { shift->dec(); };

sub init {
    my ($self) = @_;

    $VERBOSE = $self->{'arg.verbose'} == 1;

    return undef;
}

sub inc {
    my ($self) = @_;

    return ++$INDENT;
}

sub dec {
    my ($self) = @_;

    return --$INDENT;
}

sub indents {
    my ($self) = @_;

    return ' ' x $INDENT;
}

sub display {
    my ( $self, $msging ) = @_;

    print $msging;

    return undef;
}

sub is_verbose {
    my ($self) = @_;

    return $VERBOSE == 1;
}

sub info_no_nl {
    my ( $self, $msg ) = @_;

    $self->display("$msg");

    return undef;
}

sub info {
    my ( $self, $msg, $notify ) = @_;

    my $str = "   $self $msg\n";

    $self->display($str);
    $notify->message_push($str) if defined $notify;

    return undef;
}

sub nl {
    my ( $self, $notify ) = @_;

    $self->display("\n");
    $notify->message_push("\n") if defined $notify;

    return undef;
}

sub error {
    my ( $self, $msg ) = @_;

    $self->display("!  ERROR: $self $msg\n");

    exit 666;

    return undef;
}

sub warning {
    my ( $self, $msg, $notify ) = @_;

    my $str = "!  $self $msg\n";

    $self->display($str);

    if ( defined $notify ) {
        $notify->message_push($str);
        $notify->{warnings}++;
    }

    return undef;
}

sub critical {
    my ( $self, $msg, $notify ) = @_;

    my $str = "!! $self $msg\n";

    $self->display($str);

    if ( defined $notify ) {
        $notify->message_push($str);
        $notify->{criticals}++;
    }

    return undef;
}

sub dump {
    my ( $self, $msg ) = @_;

    $self->display( Dumper $msg );

    return undef;
}

sub diedump {
    my ( $self, $msg ) = @_;

    die Dumper $msg;

    return undef;
}

sub verbose {
    my ( $self, $msg, $notify ) = @_;

    if ( $self->is_verbose() ) {
        my $str = "  $self $msg\n";

        $self->display($str);
        $notify->message_push($str) if defined $notify;
    }

    return undef;
}

1;

