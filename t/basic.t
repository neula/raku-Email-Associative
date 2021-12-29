use v6;
use Test;

use lib 'lib';

use Email::Associative;

my $mail-text = slurp './t/test-mails/josey-nofold';

my $mail = Email::Associative.parse($mail-text);

plan 16;

my $old-from;
is $old-from = ~$mail.header<From>, 'Andrew Josey <ajosey@rdg.opengroup.org>', "We can get a header";

my $sc = 'Simon Cozens <simon@cpan.org>';
is ($mail.header<From> = $sc), $sc, "Setting returns new value";
is $mail.header<From>, $sc, "Which is consistently returned";
ok defined($mail.header.Str.index($sc)), 'stringified header object contains new "From" header';

ok $mail.header<Bogus>.so == False, "Missing header evaluates to False in boolean context.";

my $body;
ok ($body = $mail.body) ~~ m:s/Austin Group Chair/, "Body has sane stuff in it";

my $hi = "Hi there!\n";
$mail.body = $hi;
is $mail.body, $hi, "Body can be set properly";

$mail.body = $body;
$mail.header<From> = $old-from;
is ~$mail, $mail-text, "Good grief, it's round-trippable";

is Email::Associative.parse(~$mail).Str, $mail-text, "Good grief, it's still round-trippable";

$mail.header<Previously-Unknown> = 'wonderful species';
is $mail.header<Previously-Unknown>, 'wonderful species', "We can add new headers...";

ok $mail.Str ~~ m:s/Previously\-Unknown\: wonderful species/, "...that show up in the stringification";

# with odd newlines
my $nr = "\x0a\x0d";
my $nasty = "Subject: test{$nr}To: foo{$nr}{$nr}foo{$nr}";
$mail = Email::Associative.parse($nasty);
is $mail.crlf, "{$nr}", "got correct line terminator";
is $mail.body, "foo{$nr}", "got correct body";
is ~$mail, $nasty, "Round trip nasty";

$mail = Email::Associative.new(header => [:To<mail@example.com>,
					  :From<me@example.com>,
					  :Subject<test>],
			       body => 'This is a test.');
is $mail.header<To>, "mail\@example.com", 'test pair headers in create';

$mail = Email::Associative.new(header => {:To<mail2@example.com>,
					  :From<me@example.com>,
					  :Subject<test>},
			       body => 'This is a test.');
is $mail.header<To>, "mail2\@example.com", 'test hash headers in create';
