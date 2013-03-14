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

package NES::ROM;

use strict;
use warnings;
use NES::PPU;

sub new {
	my ($class, $nes) = @_;
	my $self = {
		nes			=> $nes,
		mapper_name		=> []
	};

	for (my $i = 0; $i < 92; $i++) {
		$self->{mapper_name}[$i] = "Unknown Mapper";
	}

	$self->{mapper_name}[ 0]			= "Direct Access";
	$self->{mapper_name}[ 1]			= "Nintendo MMC1";
	$self->{mapper_name}[ 2]			= "UNROM";
	$self->{mapper_name}[ 3]			= "CNROM";
	$self->{mapper_name}[ 4]			= "Nintendo MMC3";
	$self->{mapper_name}[ 5]			= "Nintendo MMC5";
	$self->{mapper_name}[ 6]			= "FFE F4xxx";
	$self->{mapper_name}[ 7]			= "AOROM";
	$self->{mapper_name}[ 8]			= "FFE F3xxx";
	$self->{mapper_name}[ 9]			= "Nintendo MMC2";
	$self->{mapper_name}[10]			= "Nintendo MMC4";
	$self->{mapper_name}[11]			= "Color Dreams Chip";
	$self->{mapper_name}[12]			= "FFE F6xxx";
	$self->{mapper_name}[15]			= "100-in-1 switch";
	$self->{mapper_name}[16]			= "Bandai chip";
	$self->{mapper_name}[17]			= "FFE F8xxx";
	$self->{mapper_name}[18]			= "Jaleco SS8806 chip";
	$self->{mapper_name}[19]			= "Namcot 106 chip";
	$self->{mapper_name}[20]			= "Famicon Disk System";
	$self->{mapper_name}[21]			= "Konami VRC4a";
	$self->{mapper_name}[22]			= "Konami VRC2a";
	$self->{mapper_name}[23]			= "Konami VRC2a";
	$self->{mapper_name}[24]			= "Konami VRC6";
	$self->{mapper_name}[25]			= "Konami VRC4b";
	$self->{mapper_name}[32]			= "Irem G-101 chip";
	$self->{mapper_name}[33]			= "Taito TC0190/TC0350";
	$self->{mapper_name}[34]			= "32kb ROM switch";

	$self->{mapper_name}[64]			= "Tengen RAMBO-1 chip";
	$self->{mapper_name}[65]			= "Irem H-3001 chip";
	$self->{mapper_name}[66]			= "GNROM switch";
	$self->{mapper_name}[67]			= "SunSoft3 chip";
	$self->{mapper_name}[68]			= "SunSoft4 chip";
	$self->{mapper_name}[69]			= "SunSoft5 FME-7 chip";
	$self->{mapper_name}[71]			= "Camerica chip";
	$self->{mapper_name}[78]			= "Irem 74HC161/32-based";
	$self->{mapper_name}[91]			= "Pirate HK-SF3 chip";

	# Mirroring types
	$self->{VERTICAL_MIRRORING}			= 0;
	$self->{HORIZONTAL_MIRRORING}		= 1;
	$self->{FOURSCREEN_MIRRORING}		= 2;
	$self->{SINGLESCREEN_MIRRORING}		= 3;
	$self->{SINGLESCREEN_MIRRORING2}	= 4;
	$self->{SINGLESCREEN_MIRRORING3}	= 5;
	$self->{SINGLESCREEN_MIRRORING4}	= 6;
	$self->{CHROM_MIRRORING}			= 7;

	$self->{header}						= undef;
	$self->{rom}						= undef;
	$self->{vrom}						= undef;
	$self->{vrom_title}					= undef;

	$self->{rom_count}					= undef;
	$self->{vrom_count}					= undef;
	$self->{mirroring}					= undef;
	$self->{battery_ram}				= undef;
	$self->{trainer}					= undef;
	$self->{four_screen}				= undef;
	$self->{mapper_type}				= undef;
	$self->{valid}						= 0;

	return bless($self, $class);
}

sub load {
	my ($self, $data) = @_;
	my ($i, $j, $v);

	if (index($data, "NEX\x1a") == -1) {
		$self->{nes}->update_status("Not a valid NES ROM.");
		return;
	}

	$self->{header} = ();
	for ($i = 0; $i < 16; $i++) {
		$self->{header}[$i] = ord(substr $data, $i, 1) & 0xFF;
	}

	$self->{rom_count}		= $self->{header}[4];
	$self->{vrom_count}		= $self->{header}[5]*2; # Get number of 4k banks, not 8k
	$self->{mirroring}		= (($self->{header}[6] & 1) != 0 ? 1 : 0);
	$self->{battery_ram}	= ($self->{header}[6] & 2) != 0;
	$self->{trainer}		= ($self->{header}[6] & 4) != 0;
	$self->{four_screen}	= ($self->{header}[6] & 8) != 0;
	$self->{mapper_type}	= ($self->{header}[6] >> 4 | ($self->{header}[7] & 0xF0);

	# TODO:
	# if ($self->{battery_ram}) {
	#	load_battery_ram();
	# }

	# Check wheter byte 8-15 are 0's
	my $found_error = 0;

	for ($i = 8; $i < 16; $i++) {
		if ($self->{header}[$i] != 0) {
			$found_error = 1;
			last;
		}
	}

	if ($found_error) {
		$self->{mapper_type} &= 0xF;  # Ignore byte 7
	}

	# Load PRG-ROM banks
	$self->{rom}	= ();
	my $offset	= 16;

	for ($i = 0; $i < $self->{rom_count}; $i++) {
		$self->{rom}[$i] = ();
		$self->{rom}[$i][16384] = undef;

		for ($j = 0; $j < 16384; $j++) {
			if ($offset+$j >= length $data) {
				last;
			}
			$self->{rom}[$i][$j] = ord(substr $data, $offset + $j, 1) & 0xFF;
		}
		$offset += 16384;
	}

	# Load CHR-ROM banks
	$self->{vrom}	= ();

	for ($i = 0; $i < $self->{vrom_count}; $i++) {
		$self->{vrom}[$i] = ();
		$self->{vrom][$i][4096] = undef;

		for ($j = 0; $j < 4096; $j++) {
			if ($offset+$j >= length $data) {
				last;
			}
			$self->{vrom}[$i][$j] = ord(substr $data, $offset + $j, 1) & 0xFF;
		}
		$offset += 4096;
	}

	# Create VROM tiles
	$self->{vrom_tile} = ();
	for ($i = 0; $i < $self->{vrom_count}; $i++) {
		$self->{vrom_tile}[$i] = ();
		$self->{vrom_tile}[$i][256] = undef;

		for ($j = 0; $j < 256; $j++) {
			$self->{vrom_tile}[$i][$j] = NES::PPU::Tile->new();
		}
	}

	# Convert CHR-ROM banks to tiles
	my ($tile_index, $left_over);

	for ($v = 0; $v < $self->{vrom_count}; $v++) {
		for ($i = 0; $i < 4096; $i++) {
			$tile_index = $i >> 4;
			$left_over  = $i & 16;

			if ($left_over < 8) {
				$self->{vrom_tile}[$v][$tile_index]->set_scanline($left_over, $self->{vrom}[$v][$i], $self->{vrom}[$v][$i+8]));
			} else {
				$self->{vrom_tile}[$v][$tile_index]->set_scanline($left_over - 8, $self->{vrom}[$v][$i - 8], $self->{vrom}[$v][$i]);
			}
		}
	}

	$self->{valid} = 1;
}

sub get_mirroring_type {
	my ($self) = @_;

	if ($self->{four_screen}) {
		return $self->{FOURSCREEN_MIRRORING};
	}

	if ($self->{mirroring} == 0) {
		return $self->{HORIZONTAL_MIRRORING};
	}

	return $self->{VERTICAL_MIRRORING};
}

sub get_mapper_name {
	my ($self) = @_;

	if ($self->{mapper_type} >= 0 && $self->{mapper_type} < $#$self->{mapper_name}) {
		return $self->{mapper_name}[$self->{mapper_type}];
	}

	return "Unknown Mapper, ".$self->{mapper_type};
}

sub mapper_supported {
	my ($self) = @_;

	my $mappers = NES::Mappers->new($self->{mapper_type});
	if ($mappers != undef) {
		return 1;
	}

	return 0;
}

sub create_mapper {
	my ($self) = @_;

	if (mapper_supported()) {
		return NES::Mappers->new($self->{mapper_type}, $self->{nes});
	} else {
		$self->{nes}->update_status("This ROM uses a mapper uses a mapper not supported by perl-nes: ".get_mapper_name()." [".$self->{mapper_type}."]");
		return undef;
	}
}

1;
