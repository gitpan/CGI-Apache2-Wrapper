package TestCGI::mp_extra;

use strict;
use warnings FATAL => 'all';
use CGI::Apache2::Wrapper;
use Apache2::RequestIO;
use Apache2::RequestRec;
use Apache2::Const -compile => qw(OK SERVER_ERROR);

sub handler {
  my $r = shift;
  my $cgi = CGI::Apache2::Wrapper->new($r);
  my $foo = $cgi->param("foo");
  my $bar = $cgi->param("bar");
  my $remote_addr = $cgi->param("remote_addr");
  my $url = $cgi->param("url");
  my $header = $cgi->param("header");

  if ($foo || $bar) {
    $r->content_type('text/plain');
    if ($foo) {
      $r->print("\tfoo => $foo\n");
    }
    if ($bar) {
      $r->print("\tbar => $bar\n");
    }
  }

  elsif ($remote_addr) {
    $r->content_type('text/plain');
    require Apache2::Connection;
    my $r_ip = $r->connection->remote_ip;
    my $cgi_ip = $cgi->remote_addr;
    my $str = join ':', $cgi_ip, $r_ip;
    $r->print("$str\n");
  }

  elsif ($url) {
    $r->content_type('text/plain');
    $r->print($cgi->url . "\n");
  }

  elsif ($header) {
    my $header = {'Content-Type' => 'text/plain; charset=utf-8',
		  'X-err_header_out' => 'err_headers_out',
		 };
    $cgi->header($header);
    $r->print("err_header_out\n");
  }

  else {
    $r->content_type('text/plain');
    $r->print("Unknown request\n");
  }

  return Apache2::Const::OK;
}

1;

__END__
