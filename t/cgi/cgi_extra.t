use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil qw(t_cmp t_debug t_write_perl_script);
use Apache::TestConfig;
use Apache::TestRequest qw(GET_BODY GET POST_BODY);
use constant WIN32 => Apache::TestConfig::WIN32;
use Cwd;
require File::Basename;
require File::Spec;

my $cwd = getcwd();
my $cgi = File::Spec->catfile(Apache::Test::vars('serverroot'),
                              qw(cgi-bin test_cgi.pl));

t_write_perl_script($cgi, <DATA>);

plan tests => 10, have_lwp && have_cgi;

my $location = '/cgi-bin';
my $script = $location . '/test_cgi.pl';
my $line_end = WIN32 ? "\r\n" : "\n";
my $filler = "0123456789" x 6400; # < 64K

ok t_cmp(POST_BODY("$script?foo=1", Content => $filler),
          "\tfoo => 1$line_end", "simple post");

ok t_cmp(GET_BODY("$script?foo=%3F&bar=hello+world"),
         "\tfoo => ?$line_end\tbar => hello world$line_end", "simple get");

my $body = POST_BODY($script, content =>
                     "aaa=$filler;foo=1;bar=2;filler=$filler");
ok t_cmp($body, "\tfoo => 1$line_end\tbar => 2$line_end",
         "simple post");

$body = POST_BODY("$script?foo=1", content =>
                  "intro=$filler&bar=2&conclusion=$filler");
ok t_cmp($body, "\tfoo => 1$line_end\tbar => 2$line_end",
         "simple post");

ok t_cmp(GET_BODY("$script?remote_addr=1"),
         ($ENV{'REMOTE_ADDR'} || '127.0.0.1') . $line_end, "remote address");

my $got = GET_BODY("$script?url=1");
ok t_cmp($got, qr{cgi-bin.*test_cgi.pl}, "url");

my $res = GET "$script?header=1";
ok t_cmp $res->code, 200, "OK";
ok t_cmp $res->header('Content-Type'),
    'text/plain; charset=utf-8',
    'Content-Type: made it';
ok t_cmp $res->header('X-err_header_out'),
    'err_headers_out',
    'X-err_header_out: made it';
ok t_cmp $res->content, 
    "err_header_out" . $line_end,
    "content OK";

__DATA__
use strict;
use File::Basename;
use warnings FATAL => 'all';
use blib;
use CGI::Apache2::Wrapper;
use File::Spec;
require File::Basename;

apreq_log("Creating CGI::Apache2::Wrapper object");
my $cgi = CGI::Apache2::Wrapper->new();

my $foo = $cgi->param("foo");
my $bar = $cgi->param("bar");
my $remote_addr = $cgi->param("remote_addr");
my $url = $cgi->param("url");
my $header = $cgi->param("header");

if ($foo || $bar) {
    print "Content-Type: text/plain\n\n";
    if ($foo) {
        apreq_log("foo => $foo");
        print "\tfoo => $foo\n";
    }
    if ($bar) {
        apreq_log("bar => $bar");
        print "\tbar => $bar\n";
    }
}

elsif ($remote_addr) {
    print "Content-Type: text/plain\n\n";
    apreq_log("Sending remote address");
    print $cgi->remote_addr . "\n";
}

elsif ($url) {
    print "Content-Type: text/plain\n\n";
    apreq_log("Sending url");
    print $cgi->url . "\n";
}

elsif ($header) {
    my $header = {'Content-Type' => 'text/plain; charset=utf-8',
                  'X-err_header_out' => 'err_headers_out',
                 };
    print $cgi->header($header);
    apreq_log("Sending custom headers");
    print "err_header_out\n";
}

else {
    print "Content-Type: text/plain\n\n";
    print "Unknown request\n";
}
    
sub apreq_log {
    my $msg = shift;
    my ($pkg, $file, $line) = caller;
    $file = basename($file);
    print STDERR "$file($line): $msg\n";
}

