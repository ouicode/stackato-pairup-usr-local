##
# name:      Module::Install::ManifestSkip
# abstract:  Generate a MANIFEST.SKIP file
# author:    Ingy döt Net <ingy@cpan.org>
# license:   perl
# copyright: 2010, 2011
# see:
# - Module::Manifest::Skip

package Module::Install::ManifestSkip;
use 5.008001;
use strict;
use warnings;

use base 'Module::Install::Base';

my $requires = "
use Module::Manifest::Skip 0.10 ();
";

our $VERSION = '0.20';
our $AUTHOR_ONLY = 1;

my $skip_file = "MANIFEST.SKIP";

sub manifest_skip {
    my $self = shift;
    return unless $self->is_admin;

    eval $requires; die $@ if $@;

    print "Writing $skip_file\n";

    open OUT, '>', $skip_file
        or die "Can't open $skip_file for output: $!";;

    print OUT Module::Manifest::Skip->new->text;

    close OUT;

    $self->clean_files('MANIFEST');
    $self->clean_files($skip_file)
        if grep /^clean$/, @_;
}

1;

=head1 SYNOPSIS

    use inc::Module::Install;

    all_from 'lib/Foo.pm';

    manifest_skip;

    WriteAll;

=head1 DESCRIPTION

This module generates a C<MANIFEST.SKIP> file for you (using
L<Module::Manifest::Skip>) that contains the common files that people do not
want in their C<MANIFEST> files. The SKIP file is generated each time that you
(the module author) run C<Makefile.PL>.

You can add your own custom entries at the top of the C<MANIFEST> file.
Just put a blank line after your entries, and they will be left alone.

This module also adds 'MANIFEST' to the C<clean_files()> list so that
C<make clean> will remove your C<MANIFEST>.

=head1 OPTIONS

If you don't plan on adding anything to the stock MANIFEST.SKIP and just want
C<make clean> to delete it, say this:

    manifest_skip 'clean';

=head1 THEORY

One school of thought for release management is that you never commit
your C<MANIFEST> file. You just generate it using C<make manifest>, right
before releasing a module, and then delete it afterwards.

This is good because you never forget to add new files to your C<MANIFEST>.
The only problems are that you always need to generate a C<MANIFEST.SKIP>
file, and you need to add C<MANIFEST> to your clean_files, or delete it by
hand. This module does these things for you.
