#!perl
# vim:ts=4:sw=4:expandtab
#
# Please read the following documents before working on tests:
# • https://build.i3wm.org/docs/testsuite.html
#   (or docs/testsuite)
#
# • https://build.i3wm.org/docs/lib-i3test.html
#   (alternatively: perldoc ./testcases/lib/i3test.pm)
#
# • https://build.i3wm.org/docs/ipc.html
#   (or docs/ipc)
#
# • http://onyxneon.com/books/modern_perl/modern_perl_a4.pdf
#   (unless you are already familiar with Perl)
#
# Test dragging containers.
use i3test i3_config => <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

focus_follows_mouse no
floating_modifier Mod1

# 2 side by side outputs
fake-outputs 1000x500+0+0P,1000x500+1000+0

bar {
    output primary
}
EOT
use i3test::XTEST;

sub start_drag {
    my ($pos_x, $pos_y) = @_;

    $x->root->warp_pointer($pos_x, $pos_y);
    sync_with_i3;

    xtest_key_press(64);        # Alt_L
    xtest_button_press(1, $pos_x, $pos_y);
    xtest_sync_with_i3;
}

sub end_drag {
    my ($pos_x, $pos_y) = @_;

    $x->root->warp_pointer($pos_x, $pos_y);
    sync_with_i3;

    xtest_button_release(1, $pos_x, $pos_y);
    xtest_key_release(64);      # Alt_L
    xtest_sync_with_i3;
}

my ($ws1, $ws2);
my ($A, $B);

###############################################################################
# Drag floating container onto an empty workspace.
###############################################################################

$ws2 = fresh_workspace(output => 1);
$ws1 = fresh_workspace(output => 0);
open_floating_window(rect => [ 30, 30, 50, 50 ]);
$A = get_focused($ws1);

start_drag(40, 40);
end_drag(1050, 50);

is(get_focused($ws2), $A, 'Floating window moved to the right workspace');
is($ws2, focused_ws, 'Empty workspace focused after floating window dragged to it');

###############################################################################
# Drag tiling container onto an empty workspace.
###############################################################################

$ws2 = fresh_workspace(output => 1);
$ws1 = fresh_workspace(output => 0);
open_window;
$A = get_focused($ws1);

start_drag(50, 50);
end_drag(1050, 50);

is(get_focused($ws2), $A, 'Tiling window moved to the right workspace');
is($ws2, focused_ws, 'Empty workspace focused after tiling window dragged to it');

###############################################################################
# Drag tiling container onto a container that closes before the drag is
# complete.
###############################################################################

$ws1 = fresh_workspace(output => 0);
$A = open_window;
open_window;

start_drag(600, 300);  # Start dragging the second window.

# Try to place it on the first window.
$x->root->warp_pointer(50, 50);
sync_with_i3;

cmd '[id=' . $A->id . '] kill';
sync_with_i3;
end_drag(50, 50);

is(@{get_ws_content($ws1)}, 1, 'One container left in ws1');

###############################################################################
# Drag tiling container onto a tiling container on an other workspace.
###############################################################################

$ws2 = fresh_workspace(output => 1);
open_window;
$B = get_focused($ws2);
$ws1 = fresh_workspace(output => 0);
open_window;
$A = get_focused($ws1);

start_drag(50, 50);
end_drag(1500, 250);  # Center of right output, inner region.

is($ws2, focused_ws, 'Workspace focused after tiling window dragged to it');
$ws2 = get_ws($ws2);
is($ws2->{focus}[0], $A, 'A focused first, dragged container kept focus');
is($ws2->{focus}[1], $B, 'B focused second');

###############################################################################
# Drag tiling container onto a floating container on an other workspace.
###############################################################################

$ws2 = fresh_workspace(output => 1);
open_floating_window;
$B = get_focused($ws2);
$ws1 = fresh_workspace(output => 0);
open_window;
$A = get_focused($ws1);

start_drag(50, 50);
end_drag(1500, 250);

is($ws2, focused_ws, 'Workspace with one floating container focused after tiling window dragged to it');
$ws2 = get_ws($ws2);
is($ws2->{focus}[0], $A, 'A focused first, dragged container kept focus');
is($ws2->{floating_nodes}[0]->{nodes}[0]->{id}, $B, 'B exists & floating');

###############################################################################
# Drag tiling container onto a bar.
###############################################################################

$ws1 = fresh_workspace(output => 0);
open_window;
$A = get_focused($ws1);
$ws2 = fresh_workspace(output => 1);
open_window;
$B = get_focused($ws2);

start_drag(1500, 250);
end_drag(1, 498);  # Bar on bottom of left output.

is($ws1, focused_ws, 'Workspace focused after tiling window dragged to its bar');
$ws1 = get_ws($ws1);
is($ws1->{focus}[0], $B, 'B focused first, dragged container kept focus');
is($ws1->{focus}[1], $A, 'A focused second');

###############################################################################
# Drag an unfocused tiling container onto it's self.
###############################################################################

$ws1 = fresh_workspace(output => 0);
open_window;
$A = get_focused($ws1);
open_window;
$B = get_focused($ws1);

start_drag(50, 50);
end_drag(450, 450);

$ws1 = get_ws($ws1);
is($ws1->{focus}[0], $B, 'B focused first, kept focus');
is($ws1->{focus}[1], $A, 'A focused second, unfocused dragged container didn\'t gain focus');

###############################################################################
# Drag an unfocused tiling container onto an occupied workspace.
###############################################################################

$ws1 = fresh_workspace(output => 0);
open_window;
$A = get_focused($ws1);
$ws2 = fresh_workspace(output => 1);
open_window;
$B = get_focused($ws2);

start_drag(50, 50);
end_drag(1500, 250);  # Center of right output, inner region.

is($ws2, focused_ws, 'Workspace remained focused after dragging unfocused container');
$ws2 = get_ws($ws2);
is($ws2->{focus}[0], $B, 'B focused first, kept focus');
is($ws2->{focus}[1], $A, 'A focused second, unfocused container didn\'t steal focus');

done_testing;
