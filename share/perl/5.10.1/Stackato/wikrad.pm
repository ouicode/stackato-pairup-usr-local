package Tmptext::Wikrad;
use strict;
use warnings;
use Curses::UI;
use Carp qw/croak/;
use File::Path qw/mkpath/;
use base 'Exporter';
our @EXPORT_OK = qw/$App/;

our $VERSION = '0.07';

=head1 NAME

Tmptext::Wikrad - efficient wiki browsing and editing

=head1 SYNOPSIS

  my $app = Tmptext::Wikrad->new(rester => $rester);
  $app->set_page( $starting_page );
  $app->run;

=cut

our $App;

sub new {
    my $class = shift;
    $App = { 
        history => [],
        save_dir => "$ENV{HOME}/wikrad",
        @_ ,
    };
    die 'rester is mandatory' unless $App->{rester};
    $App->{rester}->agent_string("wikrad/$VERSION");
    bless $App, $class;
    $App->_setup_ui;
    return $App;
}

sub run {
    my $self = shift;

    my $quitter = sub { exit };
    $self->{cui}->set_binding( $quitter, "\cq");
    $self->{cui}->set_binding( $quitter, "\cc");
    $self->{win}{viewer}->set_binding( $quitter, 'q');

    $self->{cui}->reset_curses;
    $self->{cui}->mainloop;
}

sub save_dir { 
    my $self = shift;
    my $dir = $self->{save_dir};
    unless (-d $dir) {
        mkpath $dir or die "Can't mkpath $dir: $!";
    }
    return $dir;
}

sub set_page {
    my $self = shift;
    my $page = shift;
    my $workspace = shift;
    my $no_history = shift;

    my $pb = $self->{win}{page_box};
    my $wksp = $self->{win}{workspace_box};

    unless ($no_history) {
        push @{ $self->{history} }, {
            page => $pb->text,
            wksp => $wksp->text,
            pos  => $self->{win}{viewer}{-pos},
        };
    }
    $self->set_workspace($workspace) if $workspace;
    unless (defined $page) {
        $self->{rester}->accept('text/plain');
        $page = $self->{rester}->get_homepage;
    }
    $pb->text($page);
    $self->load_page;
}

sub set_last_tagged_page {
    my $self = shift;
    my $tag  = shift;
    my $r = $self->{rester};

    $r->accept('text/plain');
    my @pages = $r->get_taggedpages($tag);
    $self->set_page(shift @pages);
}

sub download {
    my $self = shift;
    my $current_page = $self->{win}{page_box}->text;
    $self->{cui}->leave_curses;

    my $r = $self->{rester};
    
    my $dir = $self->_unique_filename($current_page);
    mkdir $dir or die "Error creating directory $dir: $!";

    my %ct = (
        html => 'text/html',
        wiki => 'text/x.socialtext-wiki',
    );

    while (my ($ext, $ct) = each %ct) {
        $r->accept($ct);
        my $file = "$dir/content.$ext";
        open my $fh, ">$file" or die "Can't open $file: $!";
        print $fh $r->get_page($current_page);
        close $fh or die "Can't open $file: $!";
    }
    
    # Fetch attachments
    $r->accept('perl_hash');
    my $attachments = $r->get_page_attachments($current_page);

    for my $a (@$attachments) {
        my $filename = "$dir/$a->{name}";
        my ( $status, $content ) = $r->_request(
            uri    => $a->{uri},
            method => 'GET',
        );
        if ($status != 200) {
            warn "Error downloading $filename: $status";
            next;
        }
        open my $fh, ">$filename" or die "Can't open $filename: $!\n";
        print $fh $content;
        close $fh or die "Error writing to $filename: $!\n";
        print "Downloaded $filename\n";
    }
}

sub _unique_filename {
    my $self = shift;
    my $original = shift;
    my $filename = $original;
    my $i = 0;
    while (-e $filename) {
        $i++;
        $filename = "$original.$i";
    }
    return $filename;
}

sub set_workspace {
    my $self = shift;
    my $wksp = shift;
    $self->{win}{workspace_box}->text($wksp);
    $self->{rester}->workspace($wksp);
}

sub go_back {
    my $self = shift;
    my $prev = pop @{ $self->{history} };
    if ($prev) {
        $self->set_page($prev->{page}, $prev->{wksp}, 1);
        $self->{win}{viewer}{-pos} = $prev->{pos};
    }
}

sub get_page {
    return $App->{win}{page_box}->text;
}

sub load_page {
    my $self = shift;
    my $current_page = $self->{win}{page_box}->text;

    if (! $current_page) {
        $self->{cui}->status('Fetching list of pages ...');
        $self->{rester}->accept('text/plain');
        my @pages = $self->{rester}->get_pages;
        $self->{cui}->nostatus;
        $App->{win}->listbox(
            -title => 'Choose a page',
            -values => \@pages,
            change_cb => sub {
                my $page = shift;
                $App->set_page($page) if $page;
            },
        );
        return;
    }

    $self->{cui}->status("Loading page $current_page ...");
    $self->{rester}->accept('text/x.socialtext-wiki');
    my $page_text = $self->{rester}->get_page($current_page);
    $page_text = $self->_render_wikitext_wafls($page_text);
    $self->{cui}->nostatus;
    $self->{win}{viewer}->text($page_text);
    $self->{win}{viewer}->cursor_to_home;
}

sub _setup_ui {
    my $self = shift;
    $self->{cui} = Curses::UI->new( -color_support => 1 );
    $self->{win} = $self->{cui}->add('main', 'Tmptext::Wikrad::Window');
    $self->{cui}->leave_curses;
}

sub _render_wikitext_wafls {
    my $self = shift;
    my $text = shift;
    my $r = $self->{rester};

    if ($text =~ m/{st_(?:iteration|project)stories: <([^>]+)>}/) {
        my $tag = $1;
        my $replace_text = "Stories for tag: '$tag':\n";
        $self->{rester}->accept('text/plain');
        my @pages = $r->get_taggedpages($tag);
    
        $replace_text .= join("\n", map {"* [$_]"} @pages);
        $replace_text .= "\n";
        $text =~ s/{st_(?:iteration|project)stories: <[^>]+>}/$replace_text/;
    }
    while ($text =~ m/{st_searchvaluetable: ([^}]+)}/g) {
        my ($start, $offset) = ($-[0], $+[0] - $-[0]);
        my $option_str = $1;
        my %opts;
        my $replace_text = '';
        while ($option_str =~ m/(\w+):<([^>]+)>/g) {
            $opts{$1} = $2;
        }
        if (my $term = $opts{criteria}) {
            $replace_text = "Stories matching '$term':\n";
            $r->query($term);
            $r->accept('text/plain');
            $self->{cui}->status("Searching for '$term' ...");
            my @pages = $r->get_pages();
            $self->{cui}->nostatus;
            $r->query(undef);
            $replace_text .= join("\n", map {"* [$_]" } @pages) . "\n";
        }
        substr($text, $start, $offset) = $replace_text if $replace_text;
    }

    return $text;
}


1;
package Tmptext::Wikrad::Listbox;
use strict;
use warnings;
use base 'Curses::UI::Listbox';
use Curses qw/KEY_ENTER/;
use Tmptext::Wikrad qw/$App/;

sub new {
    my $class = shift;
    my %args = (
        -border => 1,
        -wraparound => 1,
        -x => 5,
        -y => 2,
        -width => 50,
        @_,
    );
    die 'must be a title' unless $args{-title};
    die 'must be values' unless $args{-values};

    my $cb = delete $args{change_cb};
    $args{-onchange} = sub {
        my $w = shift;
        my $link = $w->get;
        $App->{win}->delete('listbox');
        $App->{win}->draw;
        $cb->($link) if $cb;
    };
    my $self  = $class->SUPER::new(%args);
    $self->set_binding( sub { 
        $App->{win}->delete('listbox');
        $App->{win}->draw;
    }, 'q' );

    return $self;
}

1;
package Tmptext::Wikrad::Window;
use strict;
use warnings;
use base 'Curses::UI::Window';
use Curses qw/KEY_ENTER/;
use Tmptext::Wikrad qw/$App/;
use Tmptext::Resting;
use Tmptext::EditPage;
use JSON;
use Data::Dumper;
use YAML::XS ();

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->_create_ui_widgets;
    $self->read_config;

    my ($v, $p, $w, $t) = map { $self->{$_} } 
                          qw/viewer page_box workspace_box tag_box/;
    $v->focus;
    $v->set_binding( \&choose_frontlink,         'g' );
    $v->set_binding( \&choose_backlink,          'B' );
    $v->set_binding( \&show_help,                '?' );
    $v->set_binding( \&recently_changed,         'r' );
    $v->set_binding( \&show_uri,                 'u' );
    if ($App->{config}{vim_insert_keys_start_vim}) {
        for my $key qw(i a o A) {
            $v->set_binding( sub { editor(
                command => $key,
                line => $v->{-ypos} + 1,
                col => $v->{-xpos} + 1,
            ) }, $key );
        }
        $v->set_binding( \&show_includes,        'I' );
    }
    else {
        $v->set_binding( \&show_includes,        'i' );
    }
    $v->set_binding( \&clone_page,               'c' );
    $v->set_binding( \&clone_page_from_template, 'C' );
    $v->set_binding( \&show_metadata,            'm' );
    $v->set_binding( \&add_pagetag,              'T' );
    $v->set_binding( \&new_blog_post,            'P' );
    $v->set_binding( \&change_server,            'S' );
    $v->set_binding( \&save_to_file,             'W' );
    $v->set_binding( \&search,                   's' );

    $v->set_binding( sub { editor(
        command => 'e',
        line => $v->{-ypos} + 1,
        col => $v->{-xpos} + 1,
    ) }, 'e' );
    $v->set_binding( sub { editor(
        pull_includes => 1,
        command => 'e',
        line => $v->{-ypos} + 1,
        col => $v->{-xpos} + 1,
    ) }, 'E' );
    $v->set_binding( sub { $v->focus },                 'v' );
    $v->set_binding( sub { $p->focus; $self->{cb}{page}->($p) },      'p' );
    $v->set_binding( sub { $w->focus; $self->{cb}{workspace}->($w) }, 'w' );
    $v->set_binding( sub { $t->focus; $self->{cb}{tag}->($t) },       't' );

    $v->set_binding( sub { $v->viewer_enter }, KEY_ENTER );
    $v->set_binding( sub { $App->go_back }, 'b' );

    # this n/N messes up search next/prev
    $v->set_binding( sub { $v->next_link },    'n' );
    $v->set_binding( sub { $v->prev_link },    'N' );

    $v->set_binding( sub { $v->cursor_down },  'j' );
    $v->set_binding( sub { $v->cursor_up },    'k' );
    $v->set_binding( sub { $v->cursor_right }, 'l' );
    $v->set_binding( sub { $v->cursor_left },  'h' );
    $v->set_binding( sub { $v->cursor_to_home }, '0' );
    $v->set_binding( sub { $v->cursor_to_end },  'G' );

    return $self;
}

sub show_help {
    $App->{cui}->dialog( 
        -fg => 'yellow',
        -bg => 'blue',
        -title => 'Help:',
        -message => <<EOT);
Basic Commands:
 j/k/h/l/arrow keys - move cursor
 n/N     - move to next/previous link
 ENTER   - jump to page [under cursor]
 space/- - page down/up
 b       - go back
 e       - open page for edit
 r       - choose from recently changed pages

Awesome Commands:
 0/G - move to beginning/end of page
 w   - set workspace
 p   - set page
 t   - tagged pages
 s   - search
 g   - frontlinks
 B   - backlinks
 E   - open page for edit (--pull-includes)
 u   - show the uri for the current page
 i   - show included pages
 m   - show page metadata (tags, revision)
 T   - Tag page
 c   - clone this page
 C   - clone page from template
 P   - New blog post (read tags from current page)
 S   - Change REST server

Find:
 / - find forward
 ? - find backwards 
 (Bad: find n/N conflicts with next/prev link)

Ctrl-q / Ctrl-c / q - quit
EOT
}

sub add_pagetag {
    my $r = $App->{rester};
    $App->{cui}->status('Fetching page tags ...');
    $r->accept('text/plain');
    my $page_name = $App->get_page;
    my @tags = $r->get_pagetags($page_name);
    $App->{cui}->nostatus;
    my $question = "Enter new tags, separate with commas, prefix with '-' to remove\n  ";
    if (@tags) {
        $question .= join(", ", @tags) . "\n";
    }
    my $newtags = $App->{cui}->question($question) || '';
    my @new_tags = split(/\s*,\s*/, $newtags);
    if (@new_tags) {
        $App->{cui}->status("Tagging $page_name ...");
        for my $t (@new_tags) {
            if ($t =~ s/^-//) {
                eval { $r->delete_pagetag($page_name, $t) };
            }
            else {
                $r->put_pagetag($page_name, $t);
            }
        }
        $App->{cui}->nostatus;
    }
}

sub show_metadata {
    my $r = $App->{rester};
    $App->{cui}->status('Fetching page metadata ...');
    $r->accept('application/json');
    my $page_name = $App->get_page;
    my $json_text = $r->get_page($page_name);
    my $page_data = jsonToObj($json_text);
    $App->{cui}->nostatus;
    $App->{cui}->dialog(
        -title => "$page_name metadata",
        -message => Dumper $page_data,
    );
}

sub new_blog_post {
    my $r = $App->{rester};

    (my $username = qx(id)) =~ s/^.+?\(([^)]+)\).+/$1/s;
    my @now = localtime;
    my $default_post = sprintf '%s, %4d-%02d-%02d', $username,
                               $now[5] + 1900, $now[4] + 1, $now[3];
    my $page_name = $App->{cui}->question(
        -question => 'Enter name of new blog post:',
        -answer   => $default_post,
    ) || '';
    return unless $page_name;

    $App->{cui}->status('Fetching tags ...');
    $r->accept('text/plain');
    my @tags = _get_current_tags($App->get_page);
    $App->{cui}->nostatus;

    $App->set_page($page_name);
    editor( tags => @tags );
}

sub show_uri {
    my $r = $App->{rester};
    my $uri = $r->server . '/' . $r->workspace . '/?' 
              . Tmptext::Resting::_name_to_id($App->get_page);
    $App->{cui}->dialog( -title => "Current page:", -message => " $uri" );
}

sub clone_page {
    my @args = @_; # obj, key, args
    my $template_page = $args[2] || $App->get_page;
    my $r = $App->{rester};
    $r->accept('text/x.socialtext-wiki');
    my $template = $r->get_page($template_page);
    my $new_page = $App->{cui}->question("Title for new page:");
    if ($new_page) {
        $App->{cui}->status("Creating page ...");
        $r->put_page($new_page, $template);
        my @tags = _get_current_tags($template_page);
        $r->put_pagetag($new_page, $_) for @tags;
        $App->{cui}->nostatus;

        $App->set_page($new_page);
    }
}

sub _get_current_tags {
    my $page = shift;
    my $r = $App->{rester};
    $r->accept('text/plain');
    return grep { $_ ne 'template' } $r->get_pagetags($page);
}

sub clone_page_from_template {
    my $tag = 'template';
    $App->{cui}->status('Fetching pages tagged $tag...');
    $App->{rester}->accept('text/plain');
    my @pages = $App->{rester}->get_taggedpages($tag);
    $App->{cui}->nostatus;
    $App->{win}->listbox(
        -title => 'Choose a template',
        -values => \@pages,
        change_cb => sub { clone_page(undef, undef, shift) },
    );
}

sub show_includes {
    my $r = $App->{rester};
    my $viewer = $App->{win}{viewer};
    $App->{cui}->status('Fetching included pages ...');
    my $page_text = $viewer->text;
    while($page_text =~ m/\{include:? \[(.+?)\]\}/g) {
        my $included_page = $1;
        $r->accept('text/x.socialtext-wiki');
        my $included_text = $r->get_page($included_page);
        my $new_text = "-----Included Page----- [$included_page]\n"
                       . "$included_text\n"
                       . "-----End Include----- \n";
        $page_text =~ s/{include:? \[\Q$included_page\E\]}/$new_text/;
    }
    $viewer->text($page_text);
    $App->{cui}->nostatus;
}

sub recently_changed {
    my $r = $App->{rester};
    $App->{cui}->status('Fetching recent changes ...');
    $r->accept('text/plain');
    $r->count(250);
    my @recent = $r->get_taggedpages('Recent changes');
    $r->count(0);
    $App->{cui}->nostatus;
    $App->{win}->listbox(
        -title => 'Choose a page link',
        -values => \@recent,
        change_cb => sub {
            my $link = shift;
            $App->set_page($link) if $link;
        },
    );
}

sub choose_frontlink {
    choose_link('get_frontlinks', 'page link');
}

sub choose_backlink {
    choose_link('get_backlinks', 'backlink');
}

sub choose_link {
    my $method = shift;
    my $text = shift;
    my $arg = shift;
    my $page = $App->get_page;
    $App->{cui}->status("Fetching ${text}s");
    $App->{rester}->accept('text/plain');
    my @links = $App->{rester}->$method($page, $arg);
    $App->{cui}->nostatus;
    if (@links) {
        $App->{win}->listbox(
            -title => "Choose a $text",
            -values => \@links,
            change_cb => sub {
                my $link = shift;
                $App->set_page($link) if $link;
            },
        );
    }
    else {
        $App->{cui}->error("No ${text}s");
    }
}

sub editor {
    my %extra_args = @_;
    $App->{cui}->status('Editing page');
    $App->{cui}->leave_curses;
    my $tags = delete $extra_args{tags};

    my $ep = Tmptext::EditPage->new( 
        rester => $App->{rester},
        %extra_args,
    );
    my $page = $App->get_page;
    $ep->edit_page(
        page => $page,
        ($tags ? (tags => $tags) : ()),
        ($App->{config}{prompt_for_summary} ? (
            summary_callback => sub {
                $App->{cui}->reset_curses;

                my $question = q{Edit summary? (Put '* ' at the front to }
                             . q{also signal it!).};
                my $summary = $App->{cui}->question($question);
                if ($summary and $summary =~ s/^\*\s//) {
                    eval { # server may not support it, so fail silently.
                        my $wksp = $App->{rester}->workspace;
                        my $signal = qq{"$summary" (edited {link: $wksp [$page]})};
                        $App->{cui}->status('Squirelling away signal');
                        $App->{rester}->post_signal($signal);
                    };
                    warn $@ if $@;
                }

                $App->{cui}->leave_curses;
                return $summary;
            }
        ) : ()),
    );

    $App->{cui}->reset_curses;
    $App->load_page;
}

sub workspace_change {
    my $new_wksp = $App->{win}{workspace_box}->text;
    my $r = $App->{rester};
    if ($new_wksp) {
        $App->set_page(undef, $new_wksp);
    }
    else {
        $App->{cui}->status('Fetching list of workspaces ...');
        $r->accept('text/plain');
        my @workspaces = $r->get_workspaces;
        $App->{cui}->nostatus;
        $App->{win}->listbox(
            -title => 'Choose a workspace',
            -values => \@workspaces,
            change_cb => sub {
                my $wksp = shift;
                $App->set_page(undef, $wksp);
            },
        );
    }
}

sub tag_change {
    my $r = $App->{rester};
    my $tag = $App->{win}{tag_box}->text;

    my $chose_tagged_page = sub {
        my $tag = shift;
        $App->{cui}->status('Fetching tagged pages ...');
        $r->accept('text/plain');
        my @pages = $r->get_taggedpages($tag);
        $App->{cui}->nostatus;
        if (@pages == 0) {
            $App->{cui}->dialog("No pages tagged '$tag' found ...");
            return;
        }
        $App->{win}->listbox(
            -title => 'Choose a tagged page',
            -values => \@pages,
            change_cb => sub {
                my $page = shift;
                $App->set_page($page) if $page;
            },
        );
    };
    if ($tag) {
        $chose_tagged_page->($tag);
    }
    else {
        $App->{cui}->status('Fetching workspace tags ...');
        $r->accept('text/plain');
        my @tags = $r->get_workspace_tags;
        $App->{cui}->nostatus;
        $App->{win}->listbox(
            -title => 'Choose a tag:',
            -values => \@tags,
            change_cb => sub {
                my $tag = shift;
                $chose_tagged_page->($tag) if $tag;
            },
        );
    }
}

sub search {
    my $r = $App->{rester};

    my $query = $App->{cui}->question( 
        -question => "Search"
    ) || return;

    $App->{cui}->status("Looking for pages matching your query");
    $r->accept('text/plain');
    $r->query($query);
    $r->order('newest');
    my @matches = $r->get_pages;
    $r->query('');
    $r->order('');
    $App->{cui}->nostatus;
    $App->{win}->listbox(
        -title => 'Choose a page link',
        -values => \@matches,
        change_cb => sub {
            my $link = shift;
            $App->set_page($link) if $link;
        },
    );
}

sub change_server {
    my $r = $App->{rester};
    my $old_server = $r->server;
    my $question = <<EOT;
Enter the REST server you'd like to use:
  (Current server: $old_server)
EOT
    my $new_server = $App->{cui}->question( 
        -question => $question,
        -answer   => $old_server,
    ) || '';
    if ($new_server and $new_server ne $old_server) {
        $r->server($new_server);
    }
}

sub save_to_file {
    my $r = $App->{rester};
    my $filename;
    eval {
        my $page_name = Tmptext::Resting::name_to_id($App->get_page);
        $filename = $App->save_dir . "/$page_name.wiki";

        open(my $fh, ">$filename") or die "Can't open $filename: $!";
        print $fh $App->{win}{viewer}->text;
        close $fh or die "Couldn't write $filename: $!";
    };
    my $msg = $@ ? "Error: $@" : "Saved to $filename";
    $App->{cui}->dialog(
        -title => "Saved page to disk",
        -message => $msg,
    );
}

sub toggle_editable {
    my $w = shift;
    my $cb = shift;
    my $readonly = $w->{'-readonly'};

    my $new_text = $w->text;
    $new_text =~ s/^\s*(.+?)\s*$/$1/;
    $w->text($new_text);

    if ($readonly) {
        $w->{last_text} = $new_text;
        $w->cursor_to_home;
        $w->focus;
    }
    else {
        $App->{win}{viewer}->focus;
    }

    $cb->() if $cb and !$readonly;

    if (! $readonly and $w->text =~ m/^\s*$/) {
        $w->text($w->{last_text}) if $w->{last_text};
    }

    $w->readonly(!$readonly);
    $w->set_binding( sub { toggle_editable($w, $cb) }, KEY_ENTER );
}

sub _create_ui_widgets {
    my $self = shift;
    my %widget_positions = (
        workspace_field => {
            -width => 18,
            -x     => 1,
        },
        page_field => {
            -width => 45,
            -x     => 32,
        },
        tag_field => {
            -width => 15,
            -x     => 85,
        },
        help_label => {
            -x => 107,
        },
        page_viewer => {
            -y => 1,
        },
    );
    
    my $win_width = $self->width;
    if ($win_width < 110 and $win_width >= 80) {
        $widget_positions{tag_field} = {
            -width => 18,
            -x     => 1,
            -y     => 1,
            label_padding => 6,
        };
        $widget_positions{help_label} = {
            -x => 32,
            -y => 1,
        };
        $widget_positions{page_viewer}{-y} = 2;
    }

    #######################################
    # Create the Workspace label and field
    #######################################
    my $wksp_cb = sub { toggle_editable( shift, \&workspace_change ) };
    $self->{cb}{workspace} = $wksp_cb;
    $self->{workspace_box} = $self->add_field('Workspace:', $wksp_cb,
        -text => $App->{rester}->workspace,
        %{ $widget_positions{workspace_field} },
    );

    #######################################
    # Create the Page label and field
    #######################################
    my $page_cb = sub { toggle_editable( shift, sub { $App->load_page } ) };
    $self->{cb}{page} = $page_cb;
    $self->{page_box} = $self->add_field('Page:', $page_cb,
        %{ $widget_positions{page_field} },
    );

    #######################################
    # Create the Tag label and field
    #######################################
    my $tag_cb = sub { toggle_editable( shift, \&tag_change ) };
    $self->{cb}{tag} = $tag_cb;
    $self->{tag_box} = $self->add_field('Tag:', $tag_cb,
        %{ $widget_positions{tag_field} },
    );

    $self->add(undef, 'Label',
        -bold => 1,
        -text => "Help: hit '?'",
        %{ $widget_positions{help_label} },
    );

    #######################################
    # Create the page Viewer
    #######################################
    $self->{viewer} = $self->add(
        'viewer', 'Tmptext::Wikrad::PageViewer',
        -border => 1,
        %{ $widget_positions{page_viewer} },
    );
}

sub listbox {
    my $self = shift;
    $App->{win}->add('listbox', 'Tmptext::Wikrad::Listbox', @_)->focus;
}

sub add_field {
    my $self = shift;
    my $desc = shift;
    my $cb = shift;
    my %args = @_;
    my $x = $args{-x} || 0;
    my $y = $args{-y} || 0;
    my $label_padding = $args{label_padding} || 0;

    $self->add(undef, 'Label',
        -bold => 1,
        -text => $desc,
        -x => $x,
        -y => $y,
    );
    $args{-x} = $x + length($desc) + 1 + $label_padding;
    my $w = $self->add(undef, 'TextEntry', 
        -singleline => 1,
        -sbborder => 1,
        -readonly => 1,
        %args,
    );
    $w->set_binding( sub { $cb->($w) }, KEY_ENTER );
    return $w;
}

sub read_config {
    my $self = shift;
    my $file = "$ENV{HOME}/.wikradrc";

    $App->{config} = {
        prompt_for_summary => 1,
        vim_insert_keys_start_vim => 0,
        %{
            -r $file
            ? YAML::XS::LoadFile($file)
            : {}
        },
    };
}

1;
package Tmptext::Wikrad::PageViewer;
use strict;
use warnings;
use Curses::UI::Common;
use base 'Curses::UI::TextEditor';
use Curses;
use Tmptext::Wikrad qw/$App/;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(
        -vscrollbar => 1,
        -wrapping => 1,
        @_,
    );

    return $self;
}

sub next_link {
    my $self = shift;
    my $pos = $self->{-pos};
    my $text = $self->get;
    my $after_text = substr($text, $pos, -1);
    if ($after_text =~ m/\[(.)/) {
        my $link_pos = $pos + $-[1];
        $self->{-pos} = $link_pos;
    }
}

sub prev_link {
    my $self = shift;
    my $pos = $self->{-pos};
    my $text = $self->get;
    my $before_text = reverse substr($text, 0, $pos);
    if ($before_text =~ m/\](.)/) {
        my $link_pos = $pos - $-[1] - 1;
        $self->{-pos} = $link_pos;
    }
}

sub viewer_enter {
    my $self = shift;
    my $pos = $self->{-pos};
    my $text = $self->get;
    my $before_pos = substr($text, 0, $pos);

    my @link_types = (
        [ '{link:? (\S+) \[' => '\]' ],
        [ '\[' => '\]' ],
    );
    my $link_text;
    my $new_wksp;
    for my $link (@link_types) {
        my ($pre, $post) = @$link;
        if ($before_pos =~ m/$pre([^$post]*)$/) {
            $link_text = $1;
            if (defined $2) {
                $link_text = $2;
                $new_wksp = $1;
            }
            my $after_pos = substr($text, $pos, -1);
            if ($after_pos =~ m/([^$post]*)$post/) {
                $link_text .= $1;
            }
            else {
                $link_text = undef;
                $new_wksp  = undef;
            }
        }
        last if $link_text;
    }

    $App->set_page($link_text, $new_wksp) if $link_text;
}

sub readonly($;)
{   
    my $this = shift;
    my $readonly = shift;

    # setup key bindings with readonly set to true
    # so we can't edit this puppy
    $this->SUPER::readonly(1);
    $this->{-readonly} = $readonly;
    return $this;
}

sub draw_text(;$)
{
    my $this = shift;
    my $no_doupdate = shift || 0;
    return $this if $Curses::UI::screen_too_small;

    # Return immediately if this object is hidden.
    return $this if $this->hidden;

    # Draw the text.
    for my $id (0 .. $this->canvasheight - 1)
    {    
	# Let there be color
        my $co = $Curses::UI::color_object;
	if ($Curses::UI::color_support) {
            my $pair = $co->get_color_pair(
                                 $this->{-fg},
                                 $this->{-bg});

            $this->{-canvasscr}->attron(COLOR_PAIR($pair));
        }

        if (defined $this->{-search_highlight} 
            and $this->{-search_highlight} == ($id+$this->{-yscrpos})) {
            $this->{-canvasscr}->attron(A_REVERSE) if (not $this->{-reverse});
            $this->{-canvasscr}->attroff(A_REVERSE) if ($this->{-reverse});
        } else {
            $this->{-canvasscr}->attroff(A_REVERSE) if (not $this->{-reverse});
            $this->{-canvasscr}->attron(A_REVERSE) if ($this->{-reverse});
        }

        my $l = $this->{-scr_lines}->[$id + $this->{-yscrpos}];
        if (defined $l)
        {
            # Get the part of the line that is in view.
            my $inscreen = '';
            my $fromxscr = '';
            if ($this->{-xscrpos} < length($l))
            {
                $fromxscr = substr($l, $this->{-xscrpos}, length($l));
                $inscreen = ($this->text_wrap(
		    $fromxscr, 
		    $this->canvaswidth, 
		    NO_WORDWRAP))->[0];
            }

            # Clear line.
            $this->{-canvasscr}->addstr(
                $id, 0, 
		" "x$this->canvaswidth
	    );

            # Strip newline
            $inscreen =~ s/\n//;
            my @segments = (
                { text => $inscreen },
            );
            my $replace_segment = sub {
                my ($i, $pre, $new, $attr, $post) = @_;
                my $old_segment = $segments[$i];
                my $old_attr = $old_segment->{attr};
                my @new_segments;
                $attr = [$attr] unless ref($attr) eq 'ARRAY';
                push @new_segments, { 
                    attr => $old_attr,
                    text => $pre,
                } if $pre;
                push @new_segments, {
                    text => $new, 
                    attr => $attr,
                };
                push @new_segments, {
                    text => $post,
                    attr => $old_attr,
                } if $post;

                splice(@segments, $i, 1, @new_segments);
            };

            my $make_color = sub {
                return COLOR_PAIR($co->get_color_pair(shift, $this->{-bg}));
            };
            my $full_line = sub {
                my ($starting, $colour) = @_;
                return {
                    regex => qr/^($starting.+)/,
                    cb => sub {
                        my ($i, @matches) = @_;
                        $replace_segment->($i, '', $matches[0], 
                                           $make_color->($colour), '');
                    },
                };
            };
            my $inline = sub {
                my ($char, $attr) = @_;
                my $backchar = reverse $char;
                return {
                    regex => qr/^(.*?\s)?(\Q$char\E\S.+\S\Q$backchar\E\s?)(.*)/,
                    cb => sub {
                        my ($i, @matches) = @_;
                        $replace_segment->($i, @matches[0, 1], $attr, $matches[2]);
                    },
                };
            };
            my @wiki_syntax = (
                $full_line->('\^+ ', 'magenta'), # heading
                $full_line->('\*+ ', 'green'),   # list
                $inline->('*', A_BOLD), 
                $inline->('_', A_UNDERLINE), 
                $inline->('-', A_STANDOUT),
                $inline->('-----', [A_STANDOUT, $make_color->('yellow')]),
                { # link
                    regex => qr/(.*?)(\[[^\]]+\])(.*)/,
                    cb => sub {
                        my ($i, @matches) = @_;
                        return unless $matches[0] or $matches[1];
                        $replace_segment->($i, @matches[0, 1], 
                                           $make_color->('blue'), $matches[2]);
                    },
                },
            );
            for my $w (@wiki_syntax) {
                my $i = 0;
                while($i < @segments) {
                    my $s = $segments[$i];
                    my $text = $s->{text};
                    if ($text =~ $w->{regex}) {
                        $w->{cb}->($i, $1, $2, $3);
                    }
                    $i++;
                }
            }

            # Display the string
            my $len = 0;
            for my $s (@segments) {
                my $a = $s->{attr} || [];
                $this->{-canvasscr}->attron($_) for @$a;
                $this->{-canvasscr}->addstr($id, $len, $s->{text});
                $this->{-canvasscr}->attroff($_) for @$a;
                $len += length($s->{text});
            }
        } else {
            last;
        }
    }

    # Move the cursor.
    # Take care of TAB's    
    if ($this->{-readonly}) 
    {
        $this->{-canvasscr}->move(
            $this->canvasheight-1,
            $this->canvaswidth-1
        );
    } else {
        my $l = $this->{-scr_lines}->[$this->{-ypos}];
        my $precursor = substr(
            $l, 
            $this->{-xscrpos},
            $this->{-xpos} - $this->{-xscrpos}
        );

        my $realxpos = scrlength($precursor);
        $this->{-canvasscr}->move(
            $this->{-ypos} - $this->{-yscrpos}, 
            $realxpos
        );
    }
    
    $this->{-canvasscr}->attroff(A_UNDERLINE) if $this->{-showlines};
    $this->{-canvasscr}->attroff(A_REVERSE) if $this->{-reverse};
    $this->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;
    return $this;
}

1;
