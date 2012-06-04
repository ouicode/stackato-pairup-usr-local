##
# name:      CogDB::App
# abstract:  CogDB App
# author:    Ingy döt Net <ingy@cpan.org>
# license:   perl
# copyright: 2012

use 5.010;
use strict;
use warnings;
use App::Cmd::Setup ();
use CogDB::Store ();

package CogDB::App;
App::Cmd::Setup->import(-app);

package CogDB::Command;
App::Cmd::Setup->import(-command);

#------------------------------------------------------------------------------#
package CogDB::Command::init;
CogDB::App->import(-command);
use Mo;
extends 'CogDB::Command';

use constant abstract => 'Initialize a new CogDB data store';
use constant usage_desc => 'cogdb init';
# use constant opt_spec => (
#     [ 'root=s' => 'CogDB root directory' ],
# );

sub execute {
    my ($self, $opts, $args) = @_;
    XXX CogDB::Store->init();
}

#------------------------------------------------------------------------------#
package CogDB::Command::add;
CogDB::App->import(-command);
use Mo;
extends 'CogDB::Command';

use constant abstract => 'Add a new <type> node to the CogDB';
use constant usage_desc => 'cogdb add <type>';
use constant opt_spec => (
    [ 'root=s' => 'CogDB root directory' ],
);

sub execute {
    my ($self, $opts, $args) = @_;
    my $type = $args->[0] or die "'cogdb add' requires a type\n";
    my $id = CogDB::Store->add($type);
    print "Added a new '$type' node: $id\n";
}

1;
