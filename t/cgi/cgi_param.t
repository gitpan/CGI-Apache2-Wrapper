use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil qw(t_cmp t_debug t_write_perl_script);
use Apache::TestConfig;
use Apache::TestRequest qw(GET_BODY UPLOAD_BODY
                           GET_BODY_ASSERT POST_BODY GET_RC GET_HEAD);
use constant WIN32 => Apache::TestConfig::WIN32;
use Cwd;
require File::Basename;
require File::Spec;

my @key_len = (5, 100, 305);
my @key_num = (5, 15, 26);
my @keys    = ('a'..'z');

my $cwd = getcwd();
my $cgi = File::Spec->catfile(Apache::Test::vars('serverroot'),
                              qw(cgi-bin test_cgi.pl));

t_write_perl_script($cgi, <DATA>);

#########################################################
# uncomment the following to test larger keys
my @big_key_len = (100, 500, 5000, 10000);
# if the above is uncommented, comment out the following
#my @big_key_len = (100, 500, 1000, 2500);
#########################################################
my @big_key_num = (5, 15, 25);
my @big_keys    = ('a'..'z');

plan tests => @key_len * @key_num + @big_key_len * @big_key_num, 
	have_lwp && have_cgi;


my $location = '/cgi-bin';
my $script = $location . '/test_cgi.pl';
my $line_end = WIN32 ? "\r\n" : "\n";
my $filler = "0123456789" x 6400; # < 64K

# GET
for my $key_len (@key_len) {
    for my $key_num (@key_num) {
        my @query = ();
        my $len = 0;

        for my $key (@keys[0..($key_num-1)]) {
            my $pair = "$key=" . 'd' x $key_len;
            $len += length($pair) - 1;
            push @query, $pair;
        }
        my $query = join ";", @query;

        t_debug "# of keys : $key_num, key_len $key_len";
        my $body = GET_BODY "$script?$query";
        ok t_cmp($body,
                 $len,
                 "GET long query");
    }

}

# POST
for my $big_key_len (@big_key_len) {
    for my $big_key_num (@big_key_num) {
        my @query = ();
        my $len = 0;

        for my $big_key (@big_keys[0..($big_key_num-1)]) {
            my $pair = "$big_key=" . 'd' x $big_key_len;
            $len += length($pair) - 1;
            push @query, $pair;
        }
        my $query = join ";", @query;

        t_debug "# of keys : $big_key_num, big_key_len $big_key_len";
        my $body = POST_BODY($script, content => $query);
        ok t_cmp($body,
                 $len,
                 "POST big data");
    }

}

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

my $len = 0;
print "Content-Type: text/plain\n\n";
apreq_log("Fetching all parameters");
for ($cgi->param) {
    my $param = $cgi->param($_);
    next unless $param;
    my $length = length($param);
    apreq_log("$_ has a value of length $length");
    $len += length($_) + $length;
}
print $len;

sub apreq_log {
    my $msg = shift;
    my ($pkg, $file, $line) = caller;
    $file = basename($file);
    print STDERR "$file($line): $msg\n";
}

