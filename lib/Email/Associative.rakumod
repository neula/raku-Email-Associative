unit class Email::Associative;

use Email::Associative::Header;
use DateTime::Format::RFC2822;

my regex body-separator {
    \x0d\x0a\x0d\x0a
    || \x0a\x0d\x0a\x0d
    || \x0a ** 2
    || \x0d ** 2
}

has $.body is rw;
has Header $.header handles <crlf>;

method Str( --> Str) {
    $!header.Str ~ $.crlf ~ $!body;
}

method parse(Str $mail) {
    my Str() ($header, $crlf, $body) = $mail.split(&body-separator, 2, :v);
    # String manipulation is too clever and shortens \x0a\x0d
    $crlf = .[^(+$_ div 2)].join('') given $crlf.ords».chr;
    $header ~= $crlf;
    self.bless(body => $body, parsed => Header.parse($header, crlf => $crlf));
}

submethod BUILD(:$!body, :$parsed) {
    if %_<header>:exists {
	$!header = Header;
    } else {
	$!header = $parsed;
    }
}
submethod TWEAK(:$header, Str :$!body) {
    return if %_<parsed>:exists;
    my %heads is Header = $header.List;
    unless %heads<Date>:exists {
	%heads<Date> = DateTime::Format::RFC2822.to-string(DateTime.now);
    }
    $!header = %heads;
}
