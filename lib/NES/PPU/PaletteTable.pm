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

package NES::PPU::PaletteTable;

use strict;
use warnings;
use Carp;

sub new {
	my ($class) = @_;
	my $self = {
		cur_table 		=> (),
		emph_table 		=> (),
		current_emph 	=> -1
	};

	return bless($self, $class);
}

sub reset {
	my ($self) = @_;

	set_emphasis(0);
}

sub load_NTSC_palette {
	my ($self) = @_;

	$self->{cur_table} = (0x525252, 0xB40000, 0xA00000, 0xB1003D, 0x740069, 0x00005B, 0x00005F, 0x001840, 0x002F10, 0x084A08,
		 0x006700, 0x124200, 0x6D2800, 0x000000, 0x000000, 0x000000, 0xC4D5E7, 0xFF4000, 0xDC0E22, 0xFF476B, 0xD7009F, 0x680AD7,
		 0x0019BC, 0x0054B1, 0x006A5B, 0x008C03, 0x00AB00, 0x2C8800, 0xA47200, 0x000000, 0x000000, 0x000000, 0xF8F8F8, 0xFFAB3C,
		 0xFF7981, 0xFF5BC5, 0xFF48F2, 0xDF49FF, 0x476DFF, 0x00B4F7, 0x00E0FF, 0x00E375, 0x03F42B, 0x78B82E, 0xE5E218, 0x787878,
		 0x000000, 0x000000, 0xFFFFFF, 0xFFF2BE, 0xF8B8B8, 0xF8B8D8, 0xFFB6FF, 0xFFC3FF, 0xC7D1FF, 0x9ADAFF, 0x88EDF8, 0x83FFDD,
		 0xB8F8B8, 0xF5F8AC, 0xFFFFB0, 0xF8D8F8, 0x000000, 0x000000);

	make_tables();
	set_emphasis(0);
}

sub load_PAL_palette {
	my ($self) =  @_;

	$self->{cur_table} = (0x525252, 0xB40000, 0xA00000, 0xB1003D, 0x740069, 0x00005B, 0x00005F, 0x001840, 0x002F10, 0x084A08,
		 0x006700, 0x124200, 0x6D2800, 0x000000, 0x000000, 0x000000, 0xC4D5E7, 0xFF4000, 0xDC0E22, 0xFF476B, 0xD7009F, 0x680AD7,
		 0x0019BC, 0x0054B1, 0x006A5B, 0x008C03, 0x00AB00, 0x2C8800, 0xA47200, 0x000000, 0x000000, 0x000000, 0xF8F8F8, 0xFFAB3C,
		 0xFF7981, 0xFF5BC5, 0xFF48F2, 0xDF49FF, 0x476DFF, 0x00B4F7, 0x00E0FF, 0x00E375, 0x03F42B, 0x78B82E, 0xE5E218, 0x787878,
		 0x000000, 0x000000, 0xFFFFFF, 0xFFF2BE, 0xF8B8B8, 0xF8B8D8, 0xFFB6FF, 0xFFC3FF, 0xC7D1FF, 0x9ADAFF, 0x88EDF8, 0x83FFDD,
		 0xB8F8B8, 0xF5F8AC, 0xFFFFB0, 0xF8D8F8, 0x000000, 0x000000);

	make_tables();
	set_emphasis(0);
}

sub make_tables {
	my ($self) = @_;

	my ($r, $g, $b, $col, $i, $r_factor, $g_factor, $b_factor);

	# Calculate a table for each possible emphasis setting
	for (my $emph = 0; $emph < 8; $emph++) {
		# Determine color component factors

		$r_factor 		= 1.0;
		$g_factor 		= 1.0;
		$b_factor 		= 1.0;

		if (($emph & 1) != 0) {
			$r_factor 	= 0.75;
			$b_factor 	= 0.75;
		}

		if (($emph & 2) != 0) {
			$r_factor	= 0.75;
			$g_factor 	= 0.75;
		}

		if (($emph & 4) != 0) {
			$g_factor 	= 0.75;
			$b_factor 	= 0.75;
		}

		$self->{emph_table}[$emph] = ();
		$self->{emph_table}[$emph] = undef;

		# Calculate table
		for ($i = 0; $i < 64; $i++) {
			$col 		= $self->{cur_table}[$i];
			$r 			= int(get_red($col)   * $r_factor);
			$g 			= int(get_green($col) * $g_factor);
			$b 			= int(get_blue($col)  * $b_factor);

			$self->{emph_table}[$emph][$i] = get_rgb($r, $g, $b);
		}
	}
}

sub set_emphasis {
	my ($self, $emph) = @_;

	if ($emph != $self->{current_emph}) {
		$self->{current_emph} = $emph;

		for (my $i = 0; $i < 64; $i++) {
			$self->{cur_table}[$i] = $self->{emph_table}[$emph][$i];
		}
	}
}

sub get_entry {
	my ($self, $yig) = @_;

	return $self->{cur_table}[$yig];
}

sub get_red {
	my ($self, $rgb) = @_;

	return ($rgb >> 16)&0xFF;
}

sub get_green {
	my ($self, $rgb) = @_;

	return ($rgb >> 8)&0xFF;
}

sub get_blue {
	my ($self, $rgb) = @_;

	return $rgb&0xFF;
}

sub get_rgb {
	my ($self, $r, $g, $b) = @_;

	return (($r << 16) | ($g << 8) | ($b));
}

sub load_default_palette {
	my ($self) = @_;

	$self->{cur_table}[ 0]		= get_rgb(117, 117, 117);
	$self->{cur_table}[ 1]		= get_rgb( 39,  27, 143);
	$self->{cur_table}[ 2]		= get_rgb(  0,   0, 171);
	$self->{cur_table}[ 3]		= get_rgb( 71,   0, 159);
	$self->{cur_table}[ 4]		= get_rgb(143,   0, 119);
	$self->{cur_table}[ 5]		= get_rgb(171,   0,  19);
	$self->{cur_table}[ 6]		= get_rgb(167,   0,   0);
	$self->{cur_table}[ 7]		= get_rgb(127,   0,   0);
	$self->{cur_table}[ 8] 		= get_rgb( 67,  47,   0);
	$self->{cur_table}[ 9] 		= get_rgb(  0,  71,   0);
	$self->{cur_table}[10]		= get_rgb(  0,  81,   0);
	$self->{cur_table}[11]		= get_rgb(  0,  63,  23);
	$self->{cur_table}[12]		= get_rgb( 27,  63,  95);
	$self->{cur_table}[13]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[14]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[15]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[16]		= get_rgb(188, 118, 118);
	$self->{cur_table}[17] 		= get_rgb(  0, 115, 239);
	$self->{cur_table}[18]		= get_rgb( 35,  59, 239);
	$self->{cur_table}[19]		= get_rgb(131,   0, 243);
	$self->{cur_table}[20] 		= get_rgb(191,   0, 191);
	$self->{cur_table}[21]		= get_rgb(231,   0,  91);
	$self->{cur_table}[22]		= get_rgb(219,  43,   0);
	$self->{cur_table}[23]		= get_rgb(203,  79,  15);
	$self->{cur_table}[24]		= get_rgb(139, 115,   0);
    $self->{cur_table}[25]		= get_rgb(  0, 151,   0);
    $self->{cur_table}[26]		= get_rgb(  0, 171,   0);
    $self->{cur_table}[27]		= get_rgb(  0, 147,  59);
	$self->{cur_table}[28]		= get_rgb(  0, 131, 139);
	$self->{cur_table}[29]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[30]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[31]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[32]		= get_rgb(255, 255, 255);
	$self->{cur_table}[33]		= get_rgb( 63, 191, 255);
	$self->{cur_table}[34]		= get_rgb( 95, 151, 255);
	$self->{cur_table}[35]		= get_rgb(167, 139, 253);
	$self->{cur_table}[36]		= get_rgb(247, 123, 255);
	$self->{cur_table}[37]		= get_rgb(255, 119, 183);
	$self->{cur_table}[38]		= get_rgb(255, 119,  99);
	$self->{cur_table}[39]		= get_rgb(255, 155,  59);
	$self->{cur_table}[40]		= get_rgb(243, 191,  63);
	$self->{cur_table}[41]		= get_rgb(131, 211,  19);
	$self->{cur_table}[42]		= get_rgb( 79, 223,  75);
	$self->{cur_table}[43]		= get_rgb( 88, 248, 152);
	$self->{cur_table}[44]		= get_rgb(  0, 235, 219);
	$self->{cur_table}[45]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[46]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[47]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[48]		= get_rgb(255, 255, 255);
	$self->{cur_table}[49]		= get_rgb(171, 231, 255);
	$self->{cur_table}[50]		= get_rgb(199, 215, 255);
	$self->{cur_table}[51]		= get_rgb(215, 203, 255);
	$self->{cur_table}[52]		= get_rgb(255, 199, 255);
	$self->{cur_table}[53]		= get_rgb(255, 199, 219);
	$self->{cur_table}[54]		= get_rgb(255, 191, 179);
	$self->{cur_table}[55]		= get_rgb(255, 219, 171);
	$self->{cur_table}[56]		= get_rgb(255, 231, 163);
	$self->{cur_table}[57]		= get_rgb(227, 255, 163);
	$self->{cur_table}[58]		= get_rgb(171, 243, 191);
	$self->{cur_table}[59]		= get_rgb(179, 255, 207);
	$self->{cur_table}[60]		= get_rgb(159, 255, 243);
	$self->{cur_table}[61]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[62]		= get_rgb(  0,   0,   0);
	$self->{cur_table}[63]		= get_rgb(  0,   0,   0);

	make_tables();
	set_emphasis(0);
}

1;