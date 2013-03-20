# perl-nes, based on Jamie Sanders' vNES
# Copyright (C) 2013 Aaron Blakely (aaron@ephasic.org || @Dark_Aaron on twitter)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package NES::UI::SDL;

use strict;
use warnings;
use SDL;
use SDL::Video;
use SDLx::App;
use SDL::Surface;
use SDLx::Rect;
use SDL::Image;

sub new {
	my ($class) = @_;
	my $self    = {};

	$self->{app} = SDLx::App->new(
		height => 480,
		width  => 640,
		depth  =>  16,
		title   => 'perl-nes: NES Emulator'
	);

	bless($self, $class);
}

sub boot_screen {
	my ($self) = @_;

	my $background = SDL::Image::load('SDL/data/images/boot.png');
	my $background_rect = SDLx::Rect->new(0,0,
	    $background->w,
	    $background->h,
	);

	SDL::Video::blit_surface($background, $background_rect, $self->{app}, $background_rect);
	SDL::Video::update_rects($self->{app}, $background_rect);

	$self->{app}->delay(1000);
}

1;