package Apache2::JSONRPC;

use strict;
use warnings;
use JSON::Syck;
use Apache2::Const qw(TAKE1 OR_ALL OK HTTP_BAD_REQUEST SERVER_ERROR);
use Apache2::RequestRec ();
use Apache2::CmdParms ();
use Apache2::RequestIO ();
use Apache2::Request ();
use Apache2::Directive ();
use Apache2::Log ();
use Apache2::Module ();
use JSON::Syck qw(Dump Load);

use base q(Apache2::Module);

our $VERSION = "0.01";

__PACKAGE__->add([ CookOptions(
    [
        'JSONRPC_Class',
        'Perl class to dispatch JSONRPC calls to.',
    ],
)]);

return 1;

sub CookOptions { return(map { CookOption(@$_) } @_); }

sub CookOption {
    my($option, $help) = @_;
    return +{
        name            =>      $option,
        func            =>      join('::', __PACKAGE__, 'SetOption'),
        args_how        =>      TAKE1,
        req_override    =>      OR_ALL,
        $help ? (errmsg =>      "$option: $help") : (),
    };
}

sub SetOption {
    my($self, $param, $value) = @_;
    $self->{$param->directive->directive} = $value;
}

##

sub config {
    my ($class, $r) = @_;
    my $dir_config = __PACKAGE__->get_config($r->server, $r->per_dir_config) || {};
    my $srv_config = __PACKAGE__->get_config($r->server) || {};
    my $config = { %$srv_config, %$dir_config };
    $config;
}

sub handler {
    my($class, $r) = @_;
    
    my $config = $class->config($r);
    
    unless($config->{JSONRPC_Class}) {
        $r->log_reason("JSONRPC_Class is not configured here!");
        return SERVER_ERROR;
    }
    
    my $length;
    unless($length = $r->headers_in->{'Content-Length'}) {
        $r->log_reason("No JSONRPC content sent!");
        return HTTP_BAD_REQUEST;
    }
    
    my $buffer = "";
    my $actual = $r->read($buffer, $length);
    
    unless($actual == $length) {
        $r->log_reason("Expected $length bytes, only got $actual back!");
        return HTTP_BAD_REQUEST;        
    }
    
    my $data = eval { (JSON::Syck::Load($buffer))[0] };
    if($@) {
        $r->log_reason($@);
        return HTTP_BAD_REQUEST;
    }
    
    unless(ref($data) && ref($data) eq 'HASH') {
        $r->log_reason("Did not get a hash from RPC request!");
        return HTTP_BAD_REQUEST;
    }
    
    unless($data->{method}) {
        $r->log_reason("JSONRPC payload did not have a method!");
        return $class->return_error($r, $data, "JSONRPC payload did not have a method!"); 
    }

    return $class->run_request($r, $config->{JSONRPC_Class}, $data);
    
}

sub run_request {
    my($class, $r, $dispatcher, $data) = @_;
    
    $data->{params} ||= [];
    my @rv = eval {
        my $method = "$dispatcher\::$data->{method}";
        warn $method;
        no strict 'refs';
        return(&{$method}($dispatcher, $data->{id}, @{$data->{params}}));
    };
    if(my $error = $@) {
        $r->log_error($error);
        return $class->return_error($r, $data, $error);
    }
    
    if(defined $data->{id}) {
        return $class->return_result($r, $data, \@rv);
    } else {
        return OK;
    }
}

sub return_result {
    my($class, $r, $data, $result) = @_;
    $r->content_type("text/json");
    $r->print(JSON::Syck::Dump({ id => $data->{id}, result => $result }));
    return OK;
}

sub return_error {
    my($class, $r, $data, $error) = @_;
    my $rv = {
        id      =>  (defined $data->{id} ? $data->{id} : undef),
        error   =>  $error
    };
    $r->content_type("text/json");
    $r->print(JSON::Syck::Dump($rv));
    return OK;
}

=pod

=head1 NAME

Apache2::JSONRPC - mod_perl handler for JSONRPC

=head1 SYNOPSIS

  <Location /json-rpc>
      SetHandler              perl-script
      PerlOptions             +GlobalRequest
      PerlResponseHandler     Apache2::JSONRPC->handler
      JSONRPC_Class           Apache2::JSONRPC::Dispatcher
  </Location>

=head1 DESCRIPTION

Apache2::JSONRPC implements the JSONRPC protocol as defined at
L<http://www.json-rpc.org/>. When a JSONRPC request is received by
this handler, it is translated into a method call. The method and
it's arguments are determined by the JSON payload coming from the
browser, and the package to call this method on is determined by
the C<JSONRPC_Class> apache config directive.

A sample "dispatcher" module is supplied, L<Apache2::JSONRPC::Dispatcher>

B<Note:> I<This is an alpha release. The interface is somewhat stable and
well-tested, but other changes may come as I work in implementing this on
my website.>

=head1 AUTHOR

Tyler "Crackerjack" MacDonald <japh@crackerjack.net> and
David Labatte <buggyd@justanotherperlhacker.com>

=head1 LICENSE

Copyright 2006 Tyler "Crackerjack" MacDonald <japh@crackerjack.net>

This is free software; You may distribute it under the same terms as perl
itself.

=head1 SEE ALSO

The "examples" directory that comes with the distribution contains a few
JSONRPC samples.

L<JSON::Syck>, L<http://www.json-rpc.org/>.

=cut
