package CogDB::Store;
use Mo 'default';
use IO::All;
use Convert::Base32 ();

has root => (default => sub {'.'});
has shortlen => (default => sub {4});

srand();

sub new_id {
    my $self = shift;
    my ($full, $short);
    my $path = $self->root . '/node';
    while (1) {
        # Base32 125bit random number.
        my $full = uc Convert::Base32::encode_base32(
            join "", map { pack "S", int(rand(65536)) } 1..8
        ); 
        $full =~ tr/IO/89/;
        chop $full;
        $full =~ s/(....)/$1-/ or die;
        $short = $1;
        next unless $short =~ /[A-Z]/ and $short =~ /[0-9]/;
        next if -e "$path/$short";
        io("$path/$short")->symlink($full);
        return $full;
    }
}

sub add {
    my ($self, $type) = @_; 
#     my $template = $self->get_schema($type)
#         or die "Can't add unknown type '$type'";
    my $id = $self->new_id;
    return $id;
#     tt->render(\$template, $data);
}
