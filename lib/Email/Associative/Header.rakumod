use Hash::Agnostic;
#use Grammar::Tracer;

unit class Email::Associative::Header does Hash::Agnostic;

grammar Grammar {
    token TOP($*crlf) { <head>+ }
    token head		{ ^^[ <field>\: <body> ] | <invalid> }
    #Printable ascii-range except colon
    token field	{ <[\x[21]..\x[39]] + [\x[3B]..\x[7E]]>+ }
    token body		{ <indent>? <notcrlf>? <crlf> <folded>* }
    token folded	{ ^^ <indent> <notcrlf> <crlf> }
    token crlf {
	| <?{ $*crlf ~~ Str:D }> $*crlf
	| <?{ $*crlf ~~ Any }> [ [\x[0D]\x[0A]]
				 | [\x[0A]\x[0D] <.warnlfcr> ]
				 | [ \x[0A] <.warnlf> ]
				 | [ \x[0D] <.warncr> ]
			       ]
    }
    token invalid	{ ^^ <notcrlf> <crlf> }
    token notcrlf	{ <-crlf>+ }
    token warnlfcr	{ <?> }
    token warnlf	{ <?> }
    token warncr	{ <?> }
    token indent	{ \h+ }
}

class Actions {
    has %.heads is rw;
    method TOP($/) {
	make %.heads;
    }
    method head($/) {
	%.heads.append: $/.<field>.Str => $/.<body>.made unless $/.<invalid>;
    }
    #TODO: Figure out what to do here
    method invalid($/) {
    }
    method body($/) {
	make [ ($/.<notcrlf>.so ?? [ $/.<notcrlf>.Str ] !! [] ).append(
	    $/.<folded>.map: *.<notcrlf>.Str).join(" ") xx 2 ];
    }
    method folded($/) {
    }
}

has $!matches;
has %!added;

has Str $.crlf;# = "\x0d\x0a";
has Int $.fold-at= 78;
has Str $.fold-indent = " ";

method AT-KEY(Str $field) is rw {
    .«$field»:exists ?? .« $field ».[(0..*).grep: * %% 2] !! %!added«$field» given $!matches.?made;
}

method EXISTS-KEY(Str $field --> Bool) {
    [||] $!matches.?made«$field»:exists, %!added«$field»:exists;
}

method DELETE-KEY(Str $field) {
    given $!matches.?made«$field»:delete {
	if .so {
	    $_;
	} else {
	    %!added«$field»:delete;
	}
    }
}

method keys() {
    [%!added.keys].append( $!matches.?made.keys // () );
}

method iterator(--> Iterator:D) {
    .iterator given %!added.append( $!matches.?made // %() );
}

method !fold($_) { .comb($!fold-at).join($!crlf ~ $!fold-indent) }

method Str(--> Str) {
    my @out;
    my %dups;
    with $!matches {
	@out.append(
	    .<head>.map: {
		%dups{ .<field> }++ unless .<invalid>;
		when .<invalid> || [===] $!matches.made{ .<field>.Str }.[%dups{ .<field> }-1,%dups{ .<field> }] {
		    .Str;
		}
		.<field>.Str ~ ": " ~ self!fold($!matches.made{ .<field> }.[%dups{ .<field> }-1]) ~ $!crlf;
	    }
	);
    }
    join('')
    <== @out.append(
	%!added.map: {
	    .key ~ ": " ~ self!fold(.value) ~ $!crlf;
	}
    )
}

method parse(Str $header-text, :$crlf) {
    my $parsed = Email::Associative::Header::Grammar.parse(
	$header-text,
	actions => Email::Associative::Header::Actions.new,
	:args(($crlf // Empty).List));
    my $found-crlf = $crlf;
#    for $parsed.<head> {
#	next without .<body>;
#	$found-crlf = $_.Str with .<body>.<crlf>;
    #    }
    self.bless(:$parsed, crlf => $found-crlf );
}

submethod BUILD(:parsed(:$!matches), :$!crlf) {}
submethod TWEAK(:headers(:%!added)) {}
