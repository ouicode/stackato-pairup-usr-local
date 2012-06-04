##
# name:      CogDB
# abstract:  A Thoughtful Data Store
# author:    Ingy döt Net <ingy@cpan.org>
# license:   perl
# copyright: 2012

use 5.010;
use strict;
use warnings;
use App::Cmd 0.313 ();
use Convert::Base32::Crockford 0.11 ();
use IO::All 0.44 ();
use Mo 0.30 ();
use Time::HiRes 0 ();
use Digest::MD5 0 ();

package CogDB;

our $VERSION = '0.01';

1;
