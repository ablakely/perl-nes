#!/usr/bin/perl -w

use lib '../../';
use strict;
use warnings;
use NES::UI::SDL;

BEGIN {
    if ( $^O eq 'darwin' && $^X !~ /SDLPerl$/ ) {
        exec 'SDLPerl', $0, @ARGV or die "Failed to exec SDLPerl: $!";
    }
}

my $ui = new NES::UI::SDL();

$ui->boot_screen();