package myAttr;

use strict;
use warnings;

use Sub::Identify qw(:all);
use Sub::Information;
use attributes;

use Data::Dumper qw(Dumper);

my %matchedFunctions;

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $subref, @attrs) = @_;
    my $info = inspect($subref);
    my $name = $info->fullname;

    my ($attr) = @attrs;
    my ($pattern) = $attr =~ /Match\((.*)\)/;

    push(@{$matchedFunctions{$name}},[$pattern, $subref]);
    
    {
        no strict qw(refs);
        *{$name} = sub {
        foreach my $head (@{$matchedFunctions{$name}}) {
                print $head->[0],"\n";
                goto $head->[1];
            }
        };
    }

    return;
}

sub Test :Match(sub{}) {
    print "This is the first one!\n";
    return 1;
}

sub Test :Match(a,b,_,4) {
    return 1;
}

Test(3);

1;