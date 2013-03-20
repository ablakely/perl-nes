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

package NES::PPU::NameTable;

use strict;
use warnings;
use Carp;

sub new {
	my ($class, $width, $height, $name) = @_;
	my $self = {
		width 		=> $width,
		height 		=> $height,
		name 		=> $name,

		tile 		=> (),
		attrib 		=> ()
	};

	$self->{tile}[$width*$height] 		= undef;
	$self->{attrib}[$width*$height] 	= undef;

	return bless($self, $class);
}

sub get_tile_index {
	my ($self, $x, $y) = @_;

	return $self->{tile}[$y * $self->{width} + $x];
}

sub get_attrib {
	my ($self, $x, $y) = @_;

	return @$self->{attrib}[$y * $self->{width} + $x];
}

sub write_attrib {
	my ($self, $index, $value) = @_;

	my $basex 		= ($index % 8) * 4;
	my $basey 		= int($index / 8) * 4;

	my ($add, $tx, $ty, $attindex);

	for (my $sqy = 0; $sqy < 2; $sqy++) {
		for (my $sqx = 0; $sqx < 2; $sqx++) {
			$add = ($value >> (2*($sqy*2+$sqx)))&3;

			for (my $y = 0; $y < 2; $y++) {
				for (my $x = 0; $x < 2; $x++) {
					$tx 										= $basex + $sqx * 2 + $x;
					$ty 										= $basey + $sqy * 2 + $y;
					$attindex 									= $ty * $self->{width} + $tx;
					$self->{attrib}[$ty * $self->{width} + $tx] = ($add << 2)&12;
				}
			}
		}
	}
}

1;