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

package NES;

use strict;
use warnings;
use NES::CPU;
use NES::ROM;
use NES::CPU;
use NES::PAPU;
use NES::UI::Dummy;

sub new {
	my ($class, %opts) = @_;

	my $opts = {
		ui			=> NES::UI::Dummy,
		prefered_frame_rate	=> 60,
		fps_interval		=> 500,   # Time between updating FPS in ms

		emulate_sound		=> 0,
		sample_rate		=> 44100, # Sound sample rate in hz

		CPU_FREQ_NTSC		=> 1789772.5,
		CPU_FREQ_PAL		=> 1773447.4
	};

	foreach my $key (keys %opts) {
		$opts->{$key} = $opts{$key};
	}

	my $self = {
		opts		=> $opts,
		ui			=> $opts->{ui}->new($self),
		cpu			=> NES::CPU->new($self),
		ppu			=> NES::PPU->new($self),
		papu		=> NES::PAPU->new($self),
		mmap		=> undef,

		is_running	=> 0,
		fps_frame_count	=> 0,
		limit_frames	=> 1,
		rom_data	=> undef
	};

	$self->{ui}->update_status("Ready to load a ROM...");

	return bless($self, $class);
};

# Resets the system
sub reset {
	my ($self) = @_;

	if ($self->mmap != undef) {
		$self->{mmap}->mmap_reset();
	}

	$self->{cpu}->cpu_reset();
	$self->{ppu}->ppu_reset();
	$self->{papu}->papu_reset();
}

sub start {
		my ($self) = @_;

		if ($self->{rom} && $self->{rom}->{valid}) {
			if (!$self->{is_running}) {
				$self->{is_running} = 1;
			}

			# TODO: SDL FPS...
		} else {
			$self->{ui}->update_status("There is no ROM loaded, or it is invalid.");
		}
}

sub frame {
		my ($self) = @_;

		my $cycles = 0;
		my $emulate_sound 	= $self->{opts}->{emulate_sound};
		my $cpu 		  	= $self->{cpu};
		my $ppu 			= $self->{ppu};
		my $papu 			= $self->{papu};

		FRAMELOOP: for (;;) {
			if ($cpu->{cycles_to_halt} == 0) {
				# Execute a CPU instruction
				$cycles = $cpu->emulate();

				if ($emulate_sound) {
					$papu->clock_frame_counter($cycles);
				}

				$cycles *= 3;
			} else {
				if ($cpu->{cycles_to_halt} > 8) {
					$cycles = 24;
					if ($emulate_sound) {
						$papu->clock_frame_counter(8);
					}

					$cpu->{cycles_to_halt} -= 8;
				} else {
					$cycles = $cpu->{cycles_to_halt} * 3;
					if ($emulate_sound) {
						$papu->clock_frame_counter($cpu->{cycles_to_halt});
					}
					$cpu->{cycles_to_halt} = 0;
				}
			}

			for (; $cycles > 0; $cycles--) {
				if ($ppu->{cur_x} == $ppu->{spr0_hit_x} && $ppu->{f_sp_visibility} == 1 && $ppu->{scanline}-21 == $ppu->{spr0_hit_y}) {
					$ppu->set_status_flag($ppu->{STATUS_SPRITE0HIT}, 1);
				}

				if ($ppu->{requested_end_frame}) {
					$ppu->{nmi_counter}--;
					if ($ppu->{nmi_counter} == 0) {
						$ppu->{requested_end_frame} = 0;
						$ppu->start_vblank();

						last FRAMELOOP;
					}
				}

				$ppu->{cur_x}++;
				if ($ppu->{cur_x} == 341) {
					$ppu->{cur_x} = 0;
					$ppu->end_scanline();
				}
			}
		}

		if ($self->limit_frames) {
			if ($self->last_frame_time) {
				# use SDL timeout for current time - last_frame_time < fame_time
				# do nothing...
			}
		}
	}

	$self->{fps_frame_count}++;
	$self->{last_frame_time} = time();
}


sub print_fps {
	# TODO...
}

sub stop {
	my ($self) = @_;

	# TODO SDL stop FPS
	$self->{is_running} = 0;
}

sub reload_rom {
	my ($self) = @_;

	if ($self->{rom_data} != 0) {
		$self->load_rom($self->{rom_data});
	}
}

# Loads a ROM file into the CPU and PPU.
# The ROM file is validated first.
sub load_rom {
	my ($self, $file) = @_;

	if ($self->{is_running}) {
		stop();
	}

	my $data;
	binmode $data;  # Since the ROM is binary, set binmode.
	open(ROM, "<", $file) or croak "Cannot open ROM file: $!\n";
	binmode ROM;
	$data = <ROM>; # Load ROM data into memory
	close ROM;

	$self->{ui}->update_status("Loading ROM...");

	# Load ROM files
	$self->{rom}	= NES::ROM->new($self);
	$self->{rom}->load($data);

	if ($self->{rom}->{valid}) {
		reset();
		$self->{mmap} = $self->{rom}->create_mapper();
		if (!$self->{mmap}) {
			return;
		}

		$self->{mmap}->loadROM();
		$self->{ppu}->set_mirroring($self->{rom}->get_mirroring_type());
		$self->{rom_data} = $data;
	} else {
		$self->{ui}->update_status("Invalid ROM file!");
	}

	return $self->{rom}->{valid};
}

sub reset_fps {
	my ($self) = @_;

	$self->{last_fps_time}   = undef;
	$self->{fps_frame_count} = 0;
}

sub set_framerate {
	my ($self, $rate) = @_;

	$self->{opts}->{prefered_frame_rate} = $rate;
	$self->{frame_time} = 1000 / $rate;
	$self->{papu}->set_sample_rate($self->{opts}->{sample_rate}, 0);
}

sub set_limit_frames {
	my ($self, $limit) = @_;

	$self->{limit_frames}		= $limit;
	$self->{last_frame_time}	= undef;
}

1;