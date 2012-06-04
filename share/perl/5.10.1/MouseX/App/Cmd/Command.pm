package MouseX::App::Cmd::Command;
use 5.006;
use strict;
use warnings;

our $VERSION = '0.11';    # VERSION
use Mouse;
use English '-no_match_vars';
use Getopt::Long::Descriptive ();
with 'MouseX::Getopt';
extends qw(Mouse::Object App::Cmd::Command);

has usage => (
    metaclass => 'NoGetopt',
    isa       => 'Object',
    is        => 'ro',
    required  => 1,
);

has app => (
    metaclass => 'NoGetopt',
    isa       => 'MouseX::App::Cmd',
    is        => 'ro',
    required  => 1,
);

sub _process_args {    ## no critic (ProhibitUnusedPrivateSubroutines)
    my ( $class, $args ) = @ARG;
    local @ARGV = @{$args};

    my $config_from_file;
    if ( $class->meta->does_role('MouseX::ConfigFromFile') ) {
        local @ARGV = @ARGV;

        my $configfile;
        my $opt_parser;
        {
            ## no critic (Modules::RequireExplicitInclusion)
            $opt_parser
                = Getopt::Long::Parser->new( config => [qw( pass_through)] );
        }
        $opt_parser->getoptions( 'configfile=s' => \$configfile );
        if ( !defined $configfile ) {
            my $cfmeta = $class->meta->find_attribute_by_name('configfile');
            if ( $cfmeta->has_default ) { $configfile = $cfmeta->default }
        }

        if ( defined $configfile ) {
            $config_from_file = $class->get_config_from_file($configfile);
        }
    }

    my %processed = $class->_parse_argv(
        params => { argv => \@ARGV },
        options => [ $class->_attrs_to_options($config_from_file) ],
    );

    my @out
        = ( $processed{params}, $processed{argv}, usage => $processed{usage},
        );

    # params from CLI are also fields in MouseX::Getopt
    if ($config_from_file) { push @out, %{$config_from_file} }
    return @out, %{ $processed{params} };
}

sub _usage_format {    ## no critic (ProhibitUnusedPrivateSubroutines)
    my $class = shift;
    return $class->usage_desc();
}

1;

# ABSTRACT: Base class for commands.

__END__

=pod

=for :stopwords Yuval Kogman Guillermo Roditi Mark Gardner Infinity Interactive cpan
testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto
metadata placeholders metacpan

=head1 NAME

MouseX::App::Cmd::Command - Base class for commands.

=head1 VERSION

version 0.11

=head1 SYNOPSIS

    use Mouse;

    extends qw(MouseX::App::Cmd::Command);

    # no need to set opt_spec
    # see MouseX::Getopt for documentation on how to specify options
    has option_field => (
        isa => "Str",
        is  => "rw",
        required => 1,
    );

    sub execute {
        my ( $self, $opts, $args ) = @_;

        print $self->option_field; # also available in $opts->{option_field}
    }

=head1 DESCRIPTION

This is a replacement base class for L<App::Cmd::Command|App::Cmd::Command>
classes that includes
L<MouseX::Getopt|MouseX::Getopt> and the glue to combine the two.

=head1 METHODS

=head2 _process_args

Replaces L<App::Cmd::Command|App::Cmd::Command>'s argument processing in in
favor of
L<MouseX::Getopt|MouseX::Getopt> based processing.

=head1 SEE ALSO

=over

=item L<App::Cmd::Command|App::Cmd::Command>

=item L<MouseX::Getopt|MouseX::Getopt>

=back

=head1 SUPPORT

=head2 Perldoc

You can find documentation for this module with the perldoc command.

  perldoc MouseX::App::Cmd

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

Search CPAN

The default CPAN search engine, useful to view POD in HTML format.

L<http://search.cpan.org/dist/MouseX-App-Cmd>

=item *

AnnoCPAN

The AnnoCPAN is a website that allows community annotations of Perl module documentation.

L<http://annocpan.org/dist/MouseX-App-Cmd>

=item *

CPAN Ratings

The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

L<http://cpanratings.perl.org/d/MouseX-App-Cmd>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.perl.org/dist/overview/MouseX-App-Cmd>

=item *

CPAN Testers

The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/M/MouseX-App-Cmd>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=MouseX-App-Cmd>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=MouseX::App::Cmd>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the web
interface at L<https://github.com/mjgardner/mousex-app-cmd/issues>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/mjgardner/mousex-app-cmd>

  git clone git://github.com/mjgardner/mousex-app-cmd.git

=head1 AUTHORS

=over 4

=item *

Yuval Kogman <nothingmuch@woobling.org>

=item *

Guillermo Roditi <groditi@cpan.org>

=item *

Mark Gardner <mjgardner@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
