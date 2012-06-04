package Convert::Base32::Crockford;
use 5.008003;
use strict;
use warnings;
use Convert::Base32 ();

use base 'Exporter';
our @EXPORT = qw(encode_base32 decode_base32);

our $VERSION = '0.11';

sub encode_base32 {
    my $base32 = Convert::Base32::encode_base32($_[0]);
    $base32 =~
    tr  {abcdefghijklmnopqrstuvwxyz234567}
        {0123456789ABCDEFGHJKMNPQRSTVWXYZ};
    return $base32;
}

sub decode_base32 {
    my $string = uc($_[0]);
    $string =~
    tr  {0O1IL23456789ABCDEFGHJKMNPQRSTVWXYZ-}
        {aabbbcdefghijklmnopqrstuvwxyz234567}d;
    return Convert::Base32::decode_base32($string);
}

1;

=head1 NAME

Convert::Base32::Crockford - Encode/Decode Strings using Crockford Base32 Scheme

=head1 SYNOPSIS

    use Digest::SHA 'sha1';
    use Convert::Base32::Crockford;

    my $foo = "foo";
    my $digest = sha1($foo);
    my $base32 = encode_base32($digest);

    die unless $digest eq decode_base32($base32);

=head1 DESCRIPTION

Base32 encoding is a human friendly way to encode binary strings. You
see these encodings all the time in URLs.

The "standard" encoding scheme is RFC 4648. L<Convert::Base32> is an
excellent module for encoding/decoding this scheme.

Douglas Crockford has proposed an alternate encoding scheme at
L<http://www.crockford.com/wrmg/base32.html>. It has many advantages,
discussed below.

=head1 API

This module is a wrapper of L<Convert::Base32>, with the exact same API,
but using the Crockford scheme.

It exports these two subroutines:

=over

=item encode_base32

    my $crockford_base32_string = encode_base32($arbitrary_string);

=item decode_base32

    my $arbitrary_string = decode_base32($crockford_base32_string);

=back

=head1 ADVANTAGES

From a computational perspective, the Crockford scheme offers no real
advantages over RFC 4648. However, from the human/usability perspective
I am convinced that the Crockford scheme is superior.

=over

=item Zero is Zero

As with most numerical base encodings (like hex), Crockford counting
starts at '0'. RFC 4648 counting starts at 'A', and '0' means 26. It
would be very challenging for most humans to count using 4648.

=item ASCII Sorting

Crockford encoded strings of equal length, will sort in the same ASCII
order as their numerical sort order.

=item Lenient Decode

The Crockford scheme allows extra characters like dash ('-') and common
mistypes like 'O' for '0', when decoding. This accomodates some human
error and also some human friendly formatting.

=item More Digits

This is a bit esoteric, but at the time of this writing, I am interested
in encodings that contain at least one letter and and least one number.
For a given length encoding, the Crockford scheme offers a bigger set of
strings that meet this requirement than RFC 4648.

=back

=head1 NOTE

There is a similarly named CPAN module called
L<Encode::Base32::Crockford>. It uses the Crockford encoding scheme but
it only works on numbers (as of the time this module was written).

Base32 and Base64 are almost always employed to encode I<binary strings>
into a human readable form. Encode::Base32::Crockford::base32_encode
dies when you try to encode a string that is not string of ASCII digits.

=head1 CREDITS

I met Douglas Crockford at the Taiwa OSDC conference in 2010. Smart guy.
Thanks for this, Douglas.

Thanks to miyagawa++ for his Convert::Base32 work.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2011. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
