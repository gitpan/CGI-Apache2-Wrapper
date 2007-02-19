package CGI::Apache2::Wrapper;
use strict;
use warnings;

our $VERSION = '0.1';
our $MOD_PERL;

sub new {
  my ($class, $r) = @_;
  if (exists $ENV{MOD_PERL}) {
    if (exists $ENV{MOD_PERL_API_VERSION} && $ENV{MOD_PERL_API_VERSION} == 2) {
      require Apache2::Response;
      require Apache2::RequestRec;
      require Apache2::RequestUtil;
      require Apache2::RequestIO;
      require APR::Pool;
      require Apache2::Request;
      $MOD_PERL = 2;
    }
    else {
      die qq{mod_perl 2 required};
    }
  }
  else {
    eval {require APR;
	  require APR::Pool;
	  require APR::Request::Param;
	  require APR::Request::CGI;};
    if ($@) {
      die qq{Error loading libarpeq2: $@};
    }
  }

  if (defined $r and ref($r) ne 'Apache2::RequestRec') {
    die qq{\$r must be an Apache2::RequestRec object};
  }

  my $self = {};
  bless $self, ref $class || $class;

  if ($MOD_PERL) {
    $r ||= Apache2::RequestUtil->request;
    $self->r($r) unless $self->r;
    $self->req(Apache2::Request->new($self->r)) unless $self->req;
  }
  else {
    $self->req(APR::Request::CGI->handle(APR::Pool->new())) unless $self->req;
  }
  $self;
}

sub r {
  my $self = shift;
  my $r = $self->{'.r'};
  $self->{'.r'} = shift if @_;
  $r;
}

sub req {
  my $self = shift;
  my $req = $self->{'.req'};
  $self->{'.req'} = shift if @_;
  $req;
}

sub param {
  my $self = shift;
  return $self->req->param(@_);
}

sub header {
  my ($self, $header_extra) = @_;
  if ($MOD_PERL) {
    my $r = $self->r;
    unless (defined $header_extra and ref($header_extra) eq 'HASH') {
      $r->content_type('text/html');
      return;
    }
    my $content_type = delete $header_extra->{'Content-Type'} || 'text/html';
    $r->content_type($content_type);
    foreach (keys %$header_extra) {
      $r->err_headers_out->add($_ => $header_extra->{$_});
    }
  }
  else {
    # borrowed from CGI.pm
    my $EBCDIC = "\t" ne "\011";
    my $CRLF;
    if ($^O eq 'VMS') {
      $CRLF = "\n";
    } 
    elsif ($EBCDIC) {
      $CRLF= "\r\n";
    } 
    else {
      $CRLF = "\015\012";
    }
    my (@header, $content_type);
    if (defined $header_extra and ref($header_extra) eq 'HASH') {
      $content_type = delete $header_extra->{'Content-Type'};
      foreach (keys %$header_extra) {
	push (@header, "$_: $header_extra->{$_}");
      }
    }
    $content_type ||= 'text/html';
    push (@header, "Content-Type: $content_type");
    my $header = join($CRLF,@header) . "${CRLF}${CRLF}";
    return $header;
  }
}

sub remote_addr {
  my $self = shift;
  if ($MOD_PERL) {
    require Apache2::Connection;
    return $self->r->connection->remote_ip;
  }
  else {
    return $ENV{'REMOTE_ADDR'} || '127.0.0.1';
  }
}

sub url {
  my $self = shift;
  if ($MOD_PERL) {
    require Apache2::URI;
    return $self->r->construct_url;
  }
  else {
    return $0;
  }
}

1;

__END__

=head1 NAME

CGI::Apache2::Wrapper - provide param() and header() via mod_perl

=head1 SYNOPSIS

  sub handler {
    my $r = shift;
    my $cgi = CGI::Apache2::Wrapper->new($r);
    my $foo = $cgi->param("foo");
    my $header = {'Content-Type' => 'text/plain; charset=utf-8',
		  'X-err_header_out' => 'err_headers_out',
		 };
    $cgi->header($header);
    $r->print("You passed in $foo\n");
    return Apache2::Const::OK;
  }

=head1 DESCRIPTION

Certain modules, such as L<CGI::Ajax> and L<JavaScript::Autocomplete::Backend>,
require a minimal CGI.pm-compatible module to provide, in particular,
the I<param()> and I<header()> methods to, respectively, fetch parameters
and to set the headers. The standard module to
do this is of course L<CGI.pm>; however, especially in a mod_perl
environment, there may be concerns with the resultant memory footprint.
This module provides I<param()> and I<header()> methods (as well
as I<remote_addr()> and I<url()> via
L<mod_perl2> and L<librapreq2>, and as such, it may be a viable
alternative in a mod_perl scenario. However, due to the nature of
the required I<APR> modules needed here, this module may also be used
in a CGI environment.

=head1 methods

Methods available are as follows.

=over

=item * my $cgi = CGI::Apache2::Wrapper-E<gt>new($r);

This method creates a I<CGI::Apache2::Wrapper> object. In a CGI environment
no arguments are passed into I<new()>, but in a mod_perl
environment, the I<Apache2::RequestRec> object I<$r> should be
passed in as an argument.

=item * my $value = $cgi-E<gt>param("foo");

This fetches the value of the named parameter. If no argument
is given to I<param()>, a list of all parameter names is returned.

=item * $cgi-E<gt>header($header);

In a mod_perl environment, this sets the headers, whereas
in a CGI environment, this returns a string containing the
headers to be printed out. If no argument is given to
I<header()>, only the I<Content-Type> is set, which by
default is I<text/html>. If a hash reference I<$header> is
passed to I<header>, such as

  my $header = {'Content-Type' => 'text/plain; charset=utf-8',
	        'X-err_header_out' => 'err_headers_out',
	       };

these will be used as the headers.

=item * my $ip = $cgi-E<gt>remote_addr();

This returns the remote IP address.

=item * my $url = $cgi-E<gt>url();

This returns the fully-qualified url, without the query string component.

=item * my $r = $cgi-E<gt>r;

This returns the I<Apache2::RequestRec> object I<$r>
passed into the I<new()> method.

=item * my $req = $cgi-E<gt>req;

This returns the I<Apache2::Request> object I<$req>, which
provides the I<param()> method to fetch form parameters.

=back

=head1 SEE ALSO

L<CGI>, L<Apache2::RequestRec>, and L<Apache2::Request>.

Development of this package takes place at
L<http://cpan-search.svn.sourceforge.net/viewvc/cpan-search/CGI-Apache2-Wrapper/>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

    perldoc CGI::Apache2::Wrapper

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CGI-Apache2-Wrapper>

=item * CPAN::Forum: Discussion forum

L<http:///www.cpanforum.com/dist/CGI-Apache2-Wrapper>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CGI-Apache2-Wrapper>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CGI-Apache2-Wrapper>

=item * Search CPAN

L<http://search.cpan.org/dist/CGI-Apache2-Wrapper>

=item * UWinnipeg CPAN Search

L<http://cpan.uwinnipeg.ca/dist/CGI-Apache2-Wrapper>

=back

=head1 COPYRIGHT

This software is copyright 2007 by Randy Kobes
E<lt>r.kobes@uwinnipeg.caE<gt>. Use and
redistribution are under the same terms as Perl itself;
see L<http://www.perl.com/pub/a/language/misc/Artistic.html>.

=cut
