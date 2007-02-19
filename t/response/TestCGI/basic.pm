package TestCGI::basic;
use strict;
use warnings;
use Apache::Test qw(-withtestmore);
use Apache::TestUtil;
use CGI::Apache2::Wrapper;
use Apache2::Const -compile => qw(OK SERVER_ERROR);
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

sub handler {
  my ($r) = @_;
  plan $r, tests => 7;
  my $cgi = CGI::Apache2::Wrapper->new($r);
  isa_ok($cgi, 'CGI::Apache2::Wrapper');
  my $cgi_r = $cgi->r;
  isa_ok($cgi_r, 'Apache2::RequestRec');
  my $cgi_req = $cgi->req;
  isa_ok($cgi_req, 'Apache2::Request');
  foreach my $method(qw(param header url remote_addr)) {
    can_ok($cgi, $method);
  }
  return Apache2::Const::OK;
}

1;

__END__
