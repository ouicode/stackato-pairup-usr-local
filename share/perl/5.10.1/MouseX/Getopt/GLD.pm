package MouseX::Getopt::GLD;
BEGIN {
  $MouseX::Getopt::GLD::AUTHORITY = 'cpan:STEVAN';
}
{
  $MouseX::Getopt::GLD::VERSION = '0.34';
}
# ABSTRACT: A Mouse role for processing command line options with Getopt::Long::Descriptive

use Mouse::Role;

use Getopt::Long::Descriptive 0.081;

with 'MouseX::Getopt::Basic';

has usage => (
    is => 'rw', isa => 'Getopt::Long::Descriptive::Usage',
    traits => ['NoGetopt'],
);

# captures the options: --help --usage --?
has help_flag => (
    is => 'ro', isa => 'Bool',
    traits => ['Getopt'],
    cmd_flag => 'help',
    cmd_aliases => [ qw(usage ?) ],
    documentation => 'Prints this usage information.',
);

around _getopt_spec => sub {
    shift;
    shift->_gld_spec(@_);
};

around _getopt_get_options => sub {
    shift;
    my ($class, $params, $opt_spec) = @_;
    return Getopt::Long::Descriptive::describe_options($class->_usage_format(%$params), @$opt_spec);
};

sub _gld_spec {
    my ( $class, %params ) = @_;

    my ( @options, %name_to_init_arg );

    my $constructor_params = $params{params};

    foreach my $opt ( @{ $params{options} } ) {
        push @options, [
            $opt->{opt_string},
            $opt->{doc} || ' ', # FIXME new GLD shouldn't need this hack
            {
                ( ( $opt->{required} && !exists($constructor_params->{$opt->{init_arg}}) ) ? (required => $opt->{required}) : () ),
                # NOTE:
                # remove this 'feature' because it didn't work
                # all the time, and so is better to not bother
                # since Mouse will handle the defaults just
                # fine anyway.
                # - SL
                #( exists $opt->{default}  ? (default  => $opt->{default})  : () ),
            },
        ];

        my $identifier = lc($opt->{name});
        $identifier =~ s/\W/_/g; # Getopt::Long does this to all option names

        $name_to_init_arg{$identifier} = $opt->{init_arg};
    }

    return ( \@options, \%name_to_init_arg );
}

no Mouse::Role;

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MouseX::Getopt::GLD - A Mouse role for processing command line options with Getopt::Long::Descriptive

=head1 SYNOPSIS

  ## In your class
  package My::App;
  use Mouse;

  with 'MouseX::Getopt::GLD';

  has 'out' => (is => 'rw', isa => 'Str', required => 1);
  has 'in'  => (is => 'rw', isa => 'Str', required => 1);

  # ... rest of the class here

  ## in your script
  #!/usr/bin/perl

  use My::App;

  my $app = My::App->new_with_options();
  # ... rest of the script here

  ## on the command line
  % perl my_app_script.pl -in file.input -out file.dump

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

