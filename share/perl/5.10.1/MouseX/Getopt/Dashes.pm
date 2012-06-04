package MouseX::Getopt::Dashes;
BEGIN {
  $MouseX::Getopt::Dashes::AUTHORITY = 'cpan:STEVAN';
}
{
  $MouseX::Getopt::Dashes::VERSION = '0.34';
}
# ABSTRACT: convert underscores in attribute names to dashes

use Mouse::Role;

with 'MouseX::Getopt';

around _get_cmd_flags_for_attr => sub {
    my $next = shift;
    my ( $class, $attr, @rest ) = @_;

    my ( $flag, @aliases ) = $class->$next($attr, @rest);
    $flag =~ tr/_/-/
        unless $attr->does('MouseX::Getopt::Meta::Attribute::Trait')
            && $attr->has_cmd_flag;

    return ( $flag, @aliases );
};

no Mouse::Role;

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MouseX::Getopt::Dashes - convert underscores in attribute names to dashes

=head1 SYNOPSIS

  package My::App;
  use Mouse;
  with 'MouseX::Getopt::Dashes';

  # Will be called as --some-thingy, not --some_thingy
  has 'some_thingy' => (
      is      => 'ro',
      isa     => 'Str',
      default => 'foo'
  );

  # Will be called as --another_thingy, not --another-thingy
  has 'another_thingy' => (
      traits   => [ 'Getopt' ],
      cmd_flag => 'another_thingy'
      is       => 'ro',
      isa      => 'Str',
      default  => 'foo'
  );

  # use as MouseX::Getopt

=head1 DESCRIPTION

This is a version of C<MouseX::Getopt> which converts underscores in
attribute names to dashes when generating command line flags.

You can selectively disable this on a per-attribute basis by supplying
a L<cmd_flag|MouseX::Getopt::Meta::Attribute/METHODS> argument with
the command flag you'd like for a given attribute. No underscore to
dash replacement will be done on the C<cmd_flag>.

=head1 AUTHORS

=over 4

=item *

NAKAGAWA Masaki <masaki@cpan.org>

=item *

FUJI Goro <gfuji@cpan.org>

=item *

Stevan Little <stevan@iinteractive.com>

=item *

Brandon L. Black <blblack@gmail.com>

=item *

Yuval Kogman <nothingmuch@woobling.org>

=item *

Ryan D Johnson <ryan@innerfence.com>

=item *

Drew Taylor <drew@drewtaylor.com>

=item *

Tomas Doran <bobtfish@bobtfish.net>

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Dagfinn Ilmari Mannsaker <ilmari@ilmari.org>

=item *

Avar Arnfjord Bjarmason <avar@cpan.org>

=item *

Chris Prather <perigrin@cpan.org>

=item *

Mark Gardner <mjgardner@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Infinity Interactive, Inc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

