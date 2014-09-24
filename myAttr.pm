package myAttr;

use strict;
use warnings;

use Attribute::Handlers;

use Data::Dumper qw(Dumper);
use Sub::Call::Tail;
my %matchedFunctions;

sub checkMatch {
	my ($args, $pattern) = @_;

	my %checkMap = (
		ARRAY => sub {
			if (ref($_[0]) eq 'ARRAY') {
				return checkMatch($_[0], $_[1]);
			}
			return 0;
		},
		HASH => sub {
			if (ref($_[0]) eq 'HASH') {
				while (my ($key, $value) = each %{ $_[1] }) {
					if (exists(${ $_[0] }{$key})) {
						checkMatch([ ${ $_[0] }{$key} ], [$value]) or return 0;
					}
					else {
						return 0;
					}
				}
				return 1;
			}
			return 0;
		},
		CODE => sub { $_[1]->(@{ $_[2] }) },
		'\@' => sub { return if ref($_[0]) eq 'ARRAY' },
		'\%' => sub { return if ref($_[0]) eq 'HASH' },
		'\$' => sub { return if ref($_[0]) eq 'SCALAR' },
		'\&' => sub { return if ref($_[0]) eq 'CODE' },
		'_'  => sub { return 1 },
	);

	my $i = 0;
	for my $token (@{$pattern}) {
		my $item = $args->[$i];
		my $type = ref($token);
		if (exists($checkMap{$type})) {
			return unless $checkMap{$type}->($item, $token, $args, $pattern);
			next;
		}
		elsif (exists($checkMap{$token})) {
			return unless $checkMap{$token}->($item, $token, $args, $pattern);
			next;
		}
		else {
			my $sym;
			($sym = $item) =~ s{\\\\}{\\}g;
			return unless $sym eq $token;
		}
	}
	continue {
		$i++;
	}
	return 1;
}

sub checkConstraint {
       	my ($args, $pattern) = @_;
	my $i = 0;
	for my $token (@{$pattern}) {
		my $item = $args->[$i];
                next if $token eq '_';
                eval "$item$token" or return 0;
	}
	continue {
		$i++;
	}
	return 1;

}

sub Match : ATTR(CODE,BEGIN) {
	my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
        print Dumper([($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum)]);

	push(@{ $matchedFunctions{ *{$symbol}{NAME} } }, [ $data, $referent ]);

	{
		no strict qw(refs);
		*{$symbol} = sub {
			foreach my $head (@{ $matchedFunctions{ *{$symbol}{NAME} } }) {
				if (checkMatch(\@_, $head->[0])) {
					goto $head->[1];
				}
			}
			die "Could not pattern match on head!"
		};
	}

	return;
}
sub Constrain :ATTR(CODE,BEGIN) {
	my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
        print Dumper($data);

	push(@{ $matchedFunctions{ *{$symbol}{NAME} } }, [ $data, $referent ]);

	{
		no strict qw(refs);
		*{$symbol} = sub {
			foreach my $head (@{ $matchedFunctions{ *{$symbol}{NAME} } }) {
				if (checkConstraint(\@_, $head->[0])) {
					goto $head->[1];
				}
			}
			die "Could not pattern match on head!"
		};
	}

	return;
}


sub Bar : Match(0) {
	print "Done!\n";
}

sub Bar : Match(_) {
	my $x = shift;
	print $x--, "\n";
	Bar($x);
}

Bar(15);

sub Foo :Match(sub{($_[0]%3==0)&&($_[0]%5==0)}) {
        return "FizzBuzz!\n";
}
sub Foo :Match(sub{$_[0]%3==0}) {
        return "Fizz!\n";
}
sub Foo :Match(sub{$_[0]%5==0}) {
        return "Buzz!\n";
}
sub Foo :Match(7) {return "ITS SEVEN MAN\n"}
sub Foo :Match(_) {
        return "$_[0]\n";
}

print map {Foo($_)} 1..50;

sub Test : Match(32) {
	print "this is the second one.\n";
	return 1;
}

sub Test : Match(sub{return 1 if $_[0] < 100}) {
	my $num = shift;
	print "This is the first one!\n";
	tail Test(--$num);
}

sub Test : Match({a => [a, b, {c => {d => [e,f,_,g]}}]}) {
	print "This is magic!\n";
}

Test(40);
Test({ a => [ 'a', 'b', { 'c' => { 'd' => [ 'e', 'f', '32343', 'g' ] } } ] });

sub Fig :Constrain('>10','!=4') { print "Yay2!!\n"}
sub Fig :Constrain('>0','>4') { print "Yay!\n"}

Fig(12,5);
Fig(2,9);

sub A :Constrain('_','_','==30') { return 1 };
sub A : Constrain('==0','_','_') {
	$_[1] + 1;
}

sub A : Constrain('_','==0','_') {
	tail A($_[0] - 1, 1, $_[2]+1);
}

sub A : Constrain('_','_','_') {
	A($_[0] - 1, A($_[0], $_[1] - 1, $_[2]+1), $_[2]+1);
}

print A(4,3,0);
1;
