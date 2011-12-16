# vim:ts=4:sw=4:sts=4:expandtab
package TestWorker;
use strict; use warnings;
use v5.10;

use Socket qw(AF_UNIX SOCK_DGRAM PF_UNSPEC);
use IO::Handle; # for ->autoflush

use POSIX ();

use Exporter 'import';
our @EXPORT = qw(worker worker_next);

use File::Basename qw(basename);
my @x;

sub worker {
    my ($display, $x, $outdir) = @_;

    # make sure $x hangs around
    push @x, $x;

    socketpair(my $ipc_child, my $ipc, AF_UNIX, SOCK_DGRAM, PF_UNSPEC)
        or die "socketpair: $!";

    $ipc->autoflush(1);
    $ipc_child->autoflush(1);

    my $worker = {
        display => $display,
        ipc => $ipc,
    };

    my $pid = fork // die "could not fork: $!";

    if ($pid == 0) {
        close $ipc;
        undef @complete_run::CLEANUP;
        # reap dead test children
        $SIG{CHLD} = sub { waitpid -1, POSIX::WNOHANG };

        $worker->{ipc} = $ipc_child;

        require i3test;
        # TODO: recycle $x
        # unfortunately this fails currently with:
        # Could not get reply for: xcb_intern_atom_reply at X11/XCB/Atom.pm line 22.

        # $i3test::x = bless $x, 'i3test::X11';
        worker_wait($worker, $outdir);
        exit 23;

    }

    close $ipc_child;
    push @complete_run::CLEANUP, sub {
        # signal via empty line to exit itself
        syswrite($ipc, "\n") or kill('TERM', $pid);
        waitpid $pid, 0;
    };

    return $worker;

}

our $EOF = "# end of file\n";
sub worker_wait {
    my ($self, $outdir) = @_;

    my $ipc = $self->{ipc};
    my $ipc_fd = fileno($ipc);

    while (defined(my $file = $ipc->getline)) {
        chomp $file;

        exit unless $file;

        die "tried to launch nonexistend testfile $file: $!\n"
            unless -e $file;

        # start a new and self contained process:
        # whatever happens in the testfile should *NOT* effect us.

        my $pid = fork // die "could not fork: $!";
        if ($pid == 0) {
            undef @complete_run::CLEANUP;
            local $SIG{CHLD};

            $0 = $file;

            POSIX::dup2($ipc_fd, 0);
            POSIX::dup2($ipc_fd, 1);
            POSIX::dup2(1, 2);

            # get Test::Builder singleton
            my $test = Test::Builder->new;

            # Test::Builder dups stdout/stderr while loading.
            # we need to reset them here to point to $ipc
            $test->output(\*STDOUT);
            $test->failure_output(\*STDERR);
            $test->todo_output(\*STDOUT);

            @ENV{qw(DISPLAY TESTNAME OUTDIR VALGRIND STRACE COVERAGE)}
                = ($self->{display}, basename($file), $outdir, 0, 0, 0);

            package main;
            local $@;
            do "./$file";
            $test->ok(undef, "$@") if $@;

            # XXX hack, we need to trigger the read watcher once more
            # to signal eof to TAP::Parser
            print $EOF;

            exit 0;
        }
    }
}

sub worker_next {
    my ($self, $file) = @_;

    my $ipc = $self->{ipc};
    syswrite $ipc, "$file\n" or die "syswrite: $!";
}

__PACKAGE__ __END__