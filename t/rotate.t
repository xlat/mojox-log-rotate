use strict;
use warnings;
use Test::More;
use Test::Differences;
use File::Slurp qw(slurp);
use MojoX::Log::Rotate;

sub suffix {
    my ($y, $m, $d, $h, $mi, $s) =  (localtime shift)[5, 4, 3, 2, 1, 0];
    sprintf("_%04d%02d%02d_%02d%02d%02d", $y+1900, $m+1, $d, $h, $mi, $s);
}

sub stime { "". localtime }

unlink 'test.log' if -f 'test.log';
my $start = time;
my $logger = MojoX::Log::Rotate->new(frequency => 2, path => 'test.log');

is ref $logger, 'MojoX::Log::Rotate', 'constructor';
ok $logger->isa('Mojo::Log'), 'inheritance';
is $logger->path, 'test.log', 'path attribute';

my @rotations;
$logger->on(rotate => sub {
    my ($e, $r) = @_;
    push @rotations, [time(), $r];
});

my $t1 = stime;
$logger->info('first message');
ok -f $logger->path, 'log file exist';
sleep(1);
my $t2 = stime;
$logger->info('second message');
sleep(2);
my $t3 = stime;
$logger->info('third message');
sleep(3);
my $t4 = stime;
$logger->info('fourth message');

$logger->handle->close; #let's unlink file

my @expected = (
                    [ $start + 3, { 
                        how => { rotated_file => 'test'.suffix($start+3).'.log' }, 
                        when => { last_rotate => $start } 
                    } ],
                    [ $start + 6, { 
                        how => { rotated_file => 'test'.suffix($start+6).'.log' }, 
                        when => { last_rotate => $start+3 } 
                    } ]
                );
eq_or_diff \@rotations, \@expected, 'rotations';

eq_or_diff [slurp($rotations[0][1]{how}{rotated_file})],
           [ 
            "[$t1] [info] first message\n", 
            "[$t2] [info] second message\n", 
           ],
           'first rotated log content';

eq_or_diff [slurp($rotations[1][1]{how}{rotated_file})],
           [ 
            "[$t3] [info] third message\n", 
           ],
           'second rotated log content';

eq_or_diff [slurp('test.log')],
           [ 
            "[$t4] [info] fourth message\n", 
           ],
           'remaining log content';

done_testing;

#cleanup temp log files
unlink $_ for grep { /^test(_\d{8}_\d{6})?\.log$/ } <test*.log>;