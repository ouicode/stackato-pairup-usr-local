use strict;
use warnings;
package Software::License::Custom;
{
  $Software::License::Custom::VERSION = '0.103004';
}
# ABSTRACT: custom license handler

use base 'Software::License';

use Carp;
use Text::Template;


sub new {
   my ($class, $arg) = @_;

   my $filename = delete $arg->{filename};

   my $self = $class->SUPER::new($arg);

   $self->load_sections_from($filename) if defined $filename;

   return $self;
}


sub load_sections_from {
   my ($self, $filename) = @_;

   # Sections are kept inside a hash
   $self->{'Software::License::Custom'}{section_for} = \my %section_for;

   my $current_section = '';
   open my $fh, '<', $filename or croak "open('$filename'): $!";

   while (<$fh>) {
      if (my ($section) = m{\A __ (.*) __ \n\z}mxs) {
         ($current_section = $section) =~ s/\W+//gmxs;
      }
      else {
         $section_for{$current_section} .= $_;
      }
   }
   close $fh;

   # strip last newline from all items
   s{\n\z}{}mxs for values %section_for;

   return $self;
}


sub section_data {
   my ($self, $name) = @_;
   my $section_for = $self->{'Software::License::Custom'}{section_for} ||= {};
   return unless exists $section_for->{$name};
   return unless defined $section_for->{$name};
   return \$section_for->{$name};
}


sub name       { shift->_fill_in('NAME') }
sub url        { shift->_fill_in('URL') }

sub meta_name  {
   my $self = shift;
   return 'custom' unless ref $self;
   return $self->_fill_in('META_NAME')
}

sub meta2_name {
  my $self = shift;
  return 'custom' unless ref $self;
  $self->_fill_in('META2_NAME')
}

sub license    { shift->_fill_in('LICENSE') }
sub notice     { shift->_fill_in('NOTICE') }

sub fulltext {
   my ($self) = @_;
   return join "\n", $self->notice, $self->license;
}

sub version {
   my ($self) = @_;
   return unless $self->section_data('VERSION');
   return $self->_fill_in('VERSION')
}

1;

__END__
=pod

=head1 NAME

Software::License::Custom - custom license handler

=head1 VERSION

version 0.103004

=head1 DESCRIPTION

This module extends L<Software::License> to give the possibility of specifying
all aspects related to a software license in a custom file.  This allows for
setting custom dates, notices, etc. while still preserving compatibility with
all places where L<Software::License> is used, e.g. L<Dist::Zilla>.

In this way, you should be able to customise some aspects of the licensing
messages that would otherwise be difficult to tinker, e.g. adding a note
in the notice, setting multiple years for the copyright notice or set multiple
authors and/or copyright holders.

The license details should be put inside a file that contains different
sections. Each section has the following format:

=over 4

=item header line

This is a line that begins and ends with two underscores C<__>. The string
between the begin and the end of the line is first depured of any non-word
character, then used as the name of the section;

=item body

a L<Text::Template> (possibly a plain text file) where items to be
expanded are enclosed between double braces

=back

Each section is terminated by the header of the following section or by
the end of the file. Example:

   __[ NAME ]__
   The Foo-Bar License
   __URL__
   http://www.example.com/foo-bar.txt
   __[ META_NAME ]__
   foo_bar_meta
   __{ META2_NAME }__
   foo_bar_meta2
   __[ NOTICE ]__
   Copyright (C) 2000-2002 by P.R. Evious
   Copyright (C) {{$self->year}} by {{$self->holder}}.

   This is free software, licensed under {{$self->name}}.

   __[ LICENSE ]__
               The Foo-Bar License

   Well... this is only some sample text.  Verily... only sample text!!!

   Yes, spanning more lines and more paragraphs.

The different formats for specifying the section name in the example
above are only examples, you're invited to use a consistent approach.

=head1 METHODS

=head2 new

   my $slc = Software::License::Custom->new({filename => 'LEGAL'});

Create a new object. Arguments are passed through an anonymous hash, the
following keys are allowed:

  filename - the file where the custom software license details are stored

=head2 load_sections_from

   $slc->load_sections_from('MY-LEGAL-ASPECTS');

Loads the different sections of the license from the provided filename.

Returns the input object.

=head2 section_data

   my $notice_template_reference = $slc->section_data('NOTICE');

Returns a reference to a textual template that can be fed to
L<Text::Template> (it could be simple text), according to what is
currently loaded in the object.

=head1 MORE METHODS

The following methods, found in all software license classes, look up and
render the template with the capitalized form of their name.  In other words,
the C<license> method looks in the C<LICENSE> template.

For now, the C<meta_name> and C<meta2_name> methods return C<custom> if called
on the class.  This may become fatal in the future.

=over 4

=item *

name

=item *

url

=item *

meta_name

=item *

meta2_name

=item *

license

=item *

notice

=item *

fulltext

=item *

version

=back

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

