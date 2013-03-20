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

package NES::PAPU;

use strict;
use warnings;
use NES::PAPU::ChannelDM;

sub new {
	my ($class, $nes) = @_;

	my $self = {
		nes                   => $nes,
		square1               => NES::PAPU::ChannelSquare->new(  $self, 1),
		square2               => NES::PAPU::ChannelSquare->new(  $self, 0),
		triangle              => NES::PAPU::ChannelTriangle->new(   $self),
		noise                 => NES::PAPU::ChannelNoise->new(      $self),
		dmc                   => NES::PAPU::ChannelDM->new(         $self),

		frame_irq_counter     => undef,
		frame_irq_counter_max => 4,
		init_counter          => 2048,
		channel_enable_value  => undef,

		buffer_size           => 8192,
		buffer_index          => 0,
		sample_rate           => 44100,

		length_lookup                => undef,
		dmc_freq_lookup              => undef,
		noise_wavelength_lookup      => undef,
		square_table                 => undef,
		tnd_table                    => undef,
		sample_buffer                => (),

		frame_irq_enabled     => 0,
		frame_irq_active      => undef,
		frame_clock_now       => undef,
		started_playing       => 0,
		record_output         => 0,
		initing_hardware      => 0,

		master_frame_counter  => undef,
		derived_frame_counter => undef,
		count_sequence        => undef,
		sample_timer          => undef,
		frame_time            => undef,
		sample_timer_max      => undef,
		sample_count          => undef,
		tri_value             => 0,

		smp_square1           => undef,
		smp_square2           => undef,
		smp_triangle          => undef,
		smp_dmc               => undef,
		acc_count             => undef,

		# DC removal vars
		prev_sampleL          => 0,
		prev_sampleR          => 0,
		smp_accumL            => 0,
		smp_accumR            => 0,

		# DAC range
		dac_range             => 0,
		dc_value              => 0,

		# Master volume
		master_volume         => 256,

		# Stereo positioning
		stereo_posL_square1   => undef,
		stereo_posL_square2   => undef,
		stereo_posL_triangle  => undef,
		stereo_posL_noise     => undef,
		stereo_posL_dmc       => undef,
		stereo_posR_square1   => undef,
		stereo_posR_square2   => undef,
		stereo_posR_triangle  => undef,
		stereo_posR_noise     => undef,
		stereo_posR_dmc       => undef,

		extra_cycles          => undef,
		max_sample            => undef,
		min_sample            => undef,

		# Panning
		panning               => [80, 170, 100, 150, 128],
	};

	set_panning($self->{panning});

	# Initialize lookup tables
	init_length_lookup();
	init_dmc_frequency_lookup();
	init_noise_wavelength_lookup();
	init_dac_tables();

	# Init sound registers
	for (my $i = 0; $i < 0x14; $i++) {
		if ($i == 0x10) {
			write_reg(0x4010, 0x10);
		} else {
			write_reg(0x4000 + $i, 0);
		}
	}

	papu_reset();

	return bless($self, $class);
}

sub papu_reset {
	my ($self) = @_;

	$self->{sample_rate} = $self->{nes}->{opts}->{sample_rate};
	$self->{sample_timer_max} = int((1024.0 * $self->{nes}->{opts}->{CPU_FREQ_NTSC} * 
		                            $self->{nes}->{opts}->{preferred_frame_rate}) / ($self->{sample_rate} * 60.0));

	$self->{frame_time} = int((14915.0 * $self->{nes}->{opts}->{preferred_frame_rate}) / 60.0);

	$self->{sample_timer} = 0;
	$self->{buffer_index} = 0;

	update_channel_enable(0);
	$self->{master_frame_counter}    = 0;
	$self->{derived_frame_counter}  = 0;
	$self->{count_sequence}         = 0;
	$self->{sample_count}           = 0;
	$self->{init_counter}           = 2048;
	$self->{frame_irq_enabled}      = 0;
	$self->{initing_hardware}       = 0;

	reset_counter();

	$self->{square1}->reset();
	$self->{square2}->reset();
	$self->{triangle}->reset();
	$self->{noise}->reset();
	$self->{dmc}->reset();

	$self->{buffer_index}			= 0;
	$self->{acc_count}				= 0;
	$self->{smp_square1}			= 0;
	$self->{smp_square2} 			= 0;
	$self->{smp_triangle}			= 0;
	$self->{smp_dmc}				= 0;

	$self->{frame_irq_enabled} 		= 0;
	$self->{frame_irq_counter_max}	= 4;

	$self->{channel_enable_value} 	= 0xFF;
	$self->{started_playing}		= 0;
	$self->{prev_sampleL}			= 0;
	$self->{prev_sampleR}			= 0;
	$self->{smp_accumL}				= 0;
	$self->{smp_accumR}				= 0;

	$self->{max_sample}				= -500000;
	$self->{min_sample}				=  500000;
}

sub read_reg {
	my ($self, $address) = @_;

	# Read 0x4015
	my $tmp = 0;
	$tmp   |= ($self->{square1}->get_length_status());
	$tmp   |= ($self->{square2}->get_length_status()  << 1);
	$tmp   |= ($self->{triangle}->get_length_status() << 2);
	$tmp   |= ($self->{noise}->get_length_status()    << 3);
	$tmp   |= ($self->{dmc}->get_length_status()      << 4);
	$tmp   |= ((($self->{frame_irq_active} && $self->{frame_irq_enabled}) ? 1 : 0) << 6);
	$tmp   |= ($self->{dmc}->get_irq_status()         << 7);

	$self->{frame_irq_active}      = 0;
	$self->{dmc}->{irq_generated}  = 0;

	return $tmp & 0xFFFF;
}

sub write_reg {
	my ($self, $address, $value) = @_;

	if ($address >= 0x4000 && $address < 0x4004) {
		# Square Wave 1 Control
		$self->{square1}->write_reg($address, $value);
	}
	elsif ($address >= 0x4004 && $address < 0x4008) {
		# Square Wave 2 Control
		$self->{square2}->write_reg($address, $value);
	} 
	elsif ($address >= 0x4008 && $address < 0x400C) {
		# Triangle control
		$self->{triangle}->write_reg($address, $value);
	}
	elsif ($address >= 0x400C && $address <= 0x400F) {
		# Noise control
		$self->{noise}->write_reg($address, $value);
	}
	elsif ($address == 0x4010) {
		# DMC Play mode & DMA frequencry
		$self->{dmc}->write_reg($address, $value);
	}
	elsif ($address == 0x4011) {
		# DMC Delta Counter
		$self->{dmc}->write_reg($address, $value);
	}
	elsif ($address == 0x4012) {
		# DMC play code starting address
		$self->{dmc}->write_reg($address, $value);
	}
	elsif ($address == 0x4013) {
		# DMC play code length
		$self->{dmc}->write_reg($address, $value);
	}
	elsif ($address == 0x4015) {
		# Channel enable
		update_channel_enable($value);

		if ($value != 0 && $self->{init_counter} > 0) {
			# Start hardware initialization
			$self->{initing_hardware} = 1;
		}

		# DMC/IRQ status
		$self->{dmc}->write_reg($address, $value);
	}
	elsif ($address == 0x4017) {
		# Frame counter control
		$self->{count_sequence} 		= ($value >> 7)&1;
		$self->{master_frame_counter}	= 0;
		$self->{frame_irq_active} 		= 0;

		if ((($value >> 6)&0x1) == 0) {
			$self->{frame_irq_enabled}  = 1;
		} else {
			$self->{frame_irq_enabled}  = 0;
		}

		if ($self->{count_sequence} == 0) {
			# NTSC
			$self->{frame_irq_counter_max} 		= 4;
			$self->{derived_frame_counter}		= 4;
		} else {
			# PAL
			$self->{frame_irq_counter_max}		= 5;
			$self->{derived_frame_counter}		= 0;
			frame_counter_tick();
		}
	}
}

sub reset_counter {
	my ($self) = @_;

	if ($self->{count_sequence} == 0) {
		$self->{derived_frame_counter} = 4;
	} else {
		$self->{derived_frame_counter} = 0;
	}
}

# Updates channel enable status.  This is done on writes
# to the channel enable register (0x4015) and when the user enables
# or disables channels in the GUI.
sub update_channel_enable {
	my ($self, $value) = @_;

	$self->{channel_enable_value} 		= $value & 0xFFFF;
	$self->{square1}->set_enabled(($value & 1) != 0);
	$self->{square2}->set_enabled(($value & 2) != 0);
	$self->{triangle}->set_enabled(($value & 4) != 0);
	$self->{noise}->set_enabled(($value & 8) != 0);
	$self->{dmc}->set_enabled(($value & 16) != 0);
}

# Clocks the frame counter.  It should be clocked at twice the CPU
# speed, so the cycles will be divided by 2 for those counters that are clocked
# at CPU speed.
sub clock_frame_counter {
	my ($self, $n_cycles) = @_;

	if ($self->{init_counter} > 0) {
		if ($self->{initing_hardware}) {
			$self->{init_counter} -= $n_cycles;
			if ($self->{init_counter} <= 0) {
				$self->initing_hardware = 0;
			}
			return;
		}
	}

	# Don't process ticks beyond next sampling
	$n_cycles      += $self->{extra_cycles};
	my $max_cycles  = $self->{sample_timer_max} - $self->{sample_timer};

	if (($n_cycles << 10) > $max_cycles) {
		$self->{extra_cycles} 		= (($n_cycles << 10) - $max_cycles) >> 10;
		$n_cycles				   -= $self->{extra_cycles};
	} else {
		$self->{extra_cycles} = 0;
	}

	my $dmc 		= $self->{dmc};
	my $triangle 	= $self->{triangle};
	my $square1 	= $self->{square1};
	my $square2 	= $self->{square2};
	my $noise 		= $self->{noise};

	# Clock DMC
	if ($dmc->{is_enabled}) {

		$dmc->{shift_counter} -= ($n_cycles << 3);
		while ($dmc->{shift_counter} <= 0 && $dmc->{dma_frequency} > 0) {
			$dmc->{shift_counter} 		+= $dmc->{dma_frequency};
			$dmc->clock_dmc();
		}
	}

	# Clock Triangle channel Prog timer
	if ($triangle->{prog_timer_max} > 0) {
		$triangle->{prog_timer_count} -= $n_cycles;

		while ($triangle->{prog_timer_count} <= 0) {

			$triangle->{prog_timer_count} += $triangle->{prog_timer_max} + 1;
			if ($triangle->{linear_counter} > 0 && $triangle->{length_counter} > 0) {

				$triangle->{triangle_counter}++;
				$triangle->{triangle_counter} &= 0x1F;

				if ($triangle->{is_enabled}) {
					if ($triangle->{triangle_counter} >= 0x10) {
						# Normal value

						$triangle->{sample_value} 		= ($triangle->{triangle_counter}&0xF);
					} else {
						# Inverted value

						$triangle->{sample_value} 		= (0xF - ($triangle->{triangle_counter}&0xF));
					}
					$triangle->{sample_value} <<= 4;
				}
			}
		}
	}

	# Clock Square channel 1 Prog Timer
	$square1->{prog_timer_count} -= $n_cycles;

	if ($square1->{prog_timer_count} <= 0) {
		$square1->{prog_timer_count} += ($square1->{prog_timer_max} +1) << 1;

		$square1->{square_counter}++;
		$square1->{square_counter} &= 0x7;
		$square1->update_sample_value();
	}

	# Clock Square channel 2 Prog timer
	$square2->{prog_timer_count}  -= $n_cycles;

	if ($square2->{prog_timer_count} <= 0) {
		$square2->{prog_timer_count} += ($square2->{prog_timer_max} + 1) << 1;

		$square2->{square_counter}++;
		$square2->{square_counter} &= 0x7;
		$square2->update_sample_value();
	}

	# Clock noise channel Prog timer
	my $acc_c = $n_cycles;

	if ($noise->{prog_timer_count} - $acc_c > 0) {

		# Do all cycles at once
		$noise->{prog_timer_count} 			-= $acc_c;
		$noise->{acc_count}					+= $acc_c;
		$noise->{acc_value}					+= $acc_c * $noise->{sample_value};
	} else {
		# Slow-step

		while (($acc_c--) > 0) {
			if (--$noise->{prog_timer_count} <= 0 && $noise->{prog_timer_max} > 0) {
				# Update noise shift register

				$noise->{shift_reg} <<= 1;
				
				# Possible bug statement:
				$noise->{tmp} = ((($noise->{shift_reg} << $noise->{random_mode} == 0 ? 1:6) ^ $noise->{shift_reg}) & 0x8000);
				
				if ($noise->{tmp} != 0) {
					# Sample values must be 0
					$noise->{shift_reg} 		|= 0x1;
					$noise->{random_bit} 		 = 0;
					$noise->{sample_value} 		 = 0;
				} else {
					# Find sample value
					$noise->{random_bit} = 1;

					if ($noise->{is_enabled} && $noise->{length_counter} > 0) {
						$noise->{sample_value} = $noise->{master_volume};
					} else {
						$noise->{sample_value} = 0;
					}
				}

				$noise->{prog_timer_count} += $noise->{prog_timer_max};
			}

			$noise->{acc_value} += $noise->{sample_value};
			$noise->{acc_count}++;
		}
	}

	# Frame IRQ handling
	if ($self->{frame_irq_enabled} && $self->{frame_irq_active}) {
		$self->{nes}->{cpu}->request_irq($self->{nes}->{cpu}->{IRQ_NORMAL});
	}

	# Clock frame counter at double CPU speed
	$self->{master_frame_counter} += ($n_cycles << 1);

	if ($this->{master_frame_counter} >= $self->{frame_time}) {
		# 240Hz tick

		$self->{master_frame_counter} -= $self->{frame_time};
		frame_counter_tick();
	}

	# Accumulate sample value
	acc_sample($n_cycle);

	# Clock sample timer
	$self->{sample_timer} += $n_cycle << 10;

	if ($self->{sample_timer} >= $self->{sample_timer_max}) {
		# sample ChannelSquare
		sample();
		$self->{sample_timer} -= $self->{sample_timer_max};
	}
}

sub acc_sample {
	my ($self, $cycles) = @_;

	# Sepecial treatment for triangle channel - need to interpolate.
	if ($self->{triangle}->{sample_condition}) {
		$self->{tri_value} = int(($self->{triangle}->{prog_timer_count} << 4) / ($self->{triangle}->{prog_timer_max} +1));

		if ($self->{tri_value} > 16) {
			$self->{tri_value} = 16;
		}

		if ($self->{triangle}->{triangle_counter} >= 16) {
			$self->{tri_value} = 16 - $self->{tri_value};
		}

		# Add non-interpolated sample value
		$self->{tri_value} += $self->{triangle}->{sample_value};
	}

	# Now sample normally
	if ($cycles == 2) {
		$self->{smp_triangle} 			+= $self->{tri_value} 				<< 1;
		$self->{smp_dmc} 				+= $self->{dmc}->{sample}			<< 1;
		$self->{smp_square1}			+= $self->{square1}->{sample_value}	<< 1;
		$self->{smp_square2}			+= $self->{square2}->{sample_value} << 1;
		$self->{acc_count} 				+= 2;
	}
	elsif ($cycles == 4) {
		$self->{smp_triangle}			+= $self->{tri_value}				<< 2;
		$self->{smp_dmc}				+= $self->{dmc}->{sample} 			<< 2;
		$self->{smp_square1}			+= $self->{square1}->{sample_value}	<< 2;
		$self->{smp_square2}			+= $self->{square2}->{sample_value} << 2;
		$self->{acc_count}				+= 4;
	} else {
		$self->{smp_triangle}			+= $cycles * $self->{tri_value};
		$self->{smp_dmc}				+= $cycles * $self->{dmc}->{sample};
		$self->{smp_square1}			+= $cycles * $self->{square1}->{sample_value};
		$self->{smp_square2}			+= $cycles * $self->{square2}->{sample_value};
		$self->{acc_count}				+= $cycles;
	}
}

sub frame_counter_tick {
	my ($self) = @_;

	$self->{derived_frame_counter}++;
	if ($self->{derived_frame_counter} >= $self->{frame_irq_counter_max}) {
		$self->{derived_frame_counter} = 0;
	}

	if ($self->{derived_frame_counter} == 1 || $self->{derived_frame_counter} == 3) {
		# Clock length & sweep
		$self->{triangle}->clock_length_counter();
		$self->{square1}->clock_length_counter();
		$self->{square2}->clock_length_counter();
		$self->{noise}->clock_length_counter();
		$self->{square1}->clock_sweep();
		$self->{square2}->clock_sweep();	
	}

	if ($self->{derived_frame_counter} >= 0 && $self->{derived_frame_counter} < 4) {
		# Clock linear & decay

		$self->{square1}->clock_env_decay();
		$self->{square2}->clock_env_decay();
		$self->{noise}->clock_env_decay();
		$self->{triangle}->clock_linear_counter();
	}

	if ($self->{derived_frame_counter} == 3 && $self->{count_sequence} == 0) {
		# Enable IRQ
		$self->{frame_irq_active} = 1;
	}

	# End of 240Hz tick
}

# Samples the channels, mixes the output together, writes
# to buffer and (if enabled) file.
sub sample {
	my ($self) = @_;

	my ($sq_index, $tnd_index);
	if ($self->{acc_count} > 0) {
		$self->{smp_square1} <<= 4;
		$self->{smp_square1}   = int($self->{smp_square1} / $self->{acc_count});

		$self->{smp_square2} <<= 4;
		$self->{smp_square2}   = int($self->{smp_square2} / $self->{acc_count});

		$self->{smp_triangle}  = int($self->{smp_triangle} / $self->{acc_count});

		$self->{smp_dmc}     <<= 4;
		$self->{smp_dmc}     <<= int($self->{smp_dmc} / $self->{acc_count});

		$self->{acc_count} = 0;

	} else {
		$self->{smp_square1} 		= $self->{square1}->{sample_value} << 4;
		$self->{smp_square2}		= $self->{square2}->{sample_value} << 4;
		$self->{smp_triangle}		= $self->{triangle}->{sample_value};
		$self->{smp_dmc}			= $self->{dmc}->{sample} << 4;
	}

	my $smp_noise = int(($self->{noise}->{acc_value} << 4) / $self->{noise}->{acc_count});

	$self->{noise}->{acc_value}  = $smp_noise >> 4;
	$self->{noise}->{acc_count}  = 1;

	# Stereo sound

	# Left channel
	$sq_index = ($self->{smp_square1} * $self->{stereo_posL_square2} + $self->{smp_square2} * $self->{stereo_posL_square2}) >> 8;
	$tnd_index = (3 * $self->{smp_triangle} * $self->{stereo_posL_triangle} + ($smp_noise << 1) * $self->{stereo_posL_noise}
		          + $self->{smp_dmc} * $self->{stereo_posL_dmc}) >> 8;

	if ($sq_index >= $#$self->{square_table}) {
		$sq_index = $#$self->{square_table} - 1;
	}
	if ($tnd_index >= $#$self->{tnd_table}) {
		$tnd_index = $#$self->{tnd_table} -1;
	}

	my $sample_valueL = $self->{square_table}[$sq_index] + $self->{tnd_table}[$tnd_index] - $self->{dc_value};

	# Right channel
	$sq_index  = ($self->{smp_square1} * $self->{stereo_posR_square1} + $self->{smp_square2} * $self->{stereo_posR_square2}) >> 8;
	$tnd_index = (3 * $self->{smp_triangle} * $self->{stereo_posR_triangle} + ($smp_noise << 1) * $self->{stereo_posR_noise} + $self->{smp_dmc} * $self->{stereo_posR_dmc}) >> 8;

	if ($sq_index >= $#$self->{square_table}) {
		$sq_index = $#$self->{square_table} - 1;
	}

	if ($tnd_index >= $#$self->{tnd_table}) {
		$tnd_index = $#$self->{tnd_table} - 1;
	}

	my $sample_valueR = $self->{square_table}[$sq_index] + $self->{tnd_table}[$tnd_index] - $self->{dc_value};

	# Remove DC from left channel:
	my $smp_diffL          = $sample_valueL - $self->{prev_sampleL};
	$self->{prev_sampleL} += $smp_diffL;
	$self->{smp_accumL}   += $smp_diffL - ($self->{smp_accumL} >> 10);
	$sample_valueL         = $self->{smp_accumL};

	# Remove DC from right channel:
	my $smp_diffR          = $sample_valueR - $self->{prev_sampleR};
	$self->{prev_sampleR} += $smp_diffR;
	$self->{smp_accumR}   += $smp_diffR - ($self->{smp_accumR} >> 10);
	$sample_valueR         = $self->{smp_accumR};

	# Write:
	if ($sample_valueL > $self->{max_sample}) {
		$self->{max_sample} = $sample_valueL;
	}

	if ($sample_valueL < $self->{min_sample}) {
		$self->{min_sample} = $sample_valueL;
	}

	$self->{sample_buffer}[$self->{buffer_index}++] = $sample_valueL;
	$self->{sample_buffer}[$self->{buffer_index}++] = $sample_valueR;

	# Write full buffer
	if ($self->{buffer_index} == $#$self->{sample_buffer}) {
		$self->{nes}->{ui}->write_audio($self->{sample_buffer});
		$self->{sample_buffer} = ();
		$self->{sample_buffer}[$self->{buffer_size} * 2] = undef;
		$self->{buffer_index} = 0;
	}

	# Reset sampled values:
	$self->{smp_square1} 				= 0;
	$self->{smp_square2}				= 0;
	$self->{smp_triangle} 				= 0;
	$self->{smp_dmc} 					= 0;
}

sub get_length_max {
	my ($self, $value) = @_;

	return $self->{length_lookup}[$value >> 3];
}

sub get_dmc_frequency {
	my ($self, $value) = @_;

	if ($value >= 0 && $value < 0x10) {
		return $self->{dmc_freq_lookup}[$value];
	}

	return 0;
}

sub get_noise_wave_length {
	my ($self, $value) = @_;

	if ($value >= 0 && $value < 0x10) {
		return $self->{noise_wavelength_lookup}[$value];
	}

	return 0;
}

sub set_panning {
	my ($self, $pos) = @_;

	for (my $i = 0; $i < 5; $i++) {
		$self->{panning}[$i] = @$pos[$i];
	}

	update_stereo_pos();
}

sub set_master_volume {
	my ($self, $value) = @_;

	if ($value < 0) {
		$value = 0;
	}

	if ($value > 256) {
		$value = 256;
	}

	$self->{master_volume} = $value;
	update_stereo_pos();
}

sub update_stereo_pos {
	my ($self) = @_;

	$self->{stereo_posL_square1}				= ($self->{panning}[0] * $self->{master_volume}) >> 8;
	$self->{stereo_posL_square2}				= ($self->{panning}[1] * $self->{master_volume}) >> 8;
	$self->{stereo_posL_triangle} 				= ($self->{panning}[2] * $self->{master_volume}) >> 8;
	$self->{stereo_posL_noise} 					= ($self->{panning}[3] * $self->{master_volume}) >> 8;
	$self->{stereo_posL_dmc}					= ($self->{panning}[4] * $self->{master_volume}) >> 8;

	$self->{stereo_posR_square1}				= $self->{master_volume} - $self->{stereo_posL_square1};
	$self->{stereo_posR_square2}				= $self->{master_volume} - $self->{stereo_posL_square2};
	$self->{stereo_posR_triangle}				= $self->{master_volume} - $self->{stereo_posL_triangle};
	$self->{stereo_posR_noise} 					= $self->{master_volume} - $self->{stereo_posL_noise};
	$self->{stereo_posR_dmc} 					= $self->{master_volume} - $self->{stereo_posL_dmc};
}

sub init_length_lookup {
	my ($self) = @_;

	$self->{length_lookup} = (
		0x0A, 0xFE, 0x14, 0x02, 0x28, 0x04, 0x50, 0x06, 0xA0, 0x08, 0x3C, 0x0A,
        0x0E, 0x0C, 0x1A, 0x0E, 0x0C, 0x10, 0x18, 0x12, 0x30, 0x14, 0x60, 0x16,
        0xC0, 0x18, 0x48, 0x1A, 0x10, 0x1C, 0x20, 0x1E
	);
}

sub init_dmc_frequency_lookup {
	my ($self) = @_;

	$self->{dmc_freq_lookup} = ();

	$self->{dmc_freq_lookup}[0x0] 		= 0xD60;
	$self->{dmc_freq_lookup}[0x1]		= 0xBE0;
	$self->{dmc_freq_lookup}[0x2]		= 0xAA0;
	$self->{dmc_freq_lookup}[0x3]		= 0xA00;
	$self->{dmc_freq_lookup}[0x4]		= 0x8F0;
	$self->{dmc_freq_lookup}[0x5]		= 0x7F0;
	$self->{dmc_freq_lookup}[0x6]		= 0x710;
	$self->{dmc_freq_lookup}[0x7]		= 0x6B0;
	$self->{dmc_freq_lookup}[0x8]		= 0x5F0;
	$self->{dmc_freq_lookup}[0x9]		= 0x500;
	$self->{dmc_freq_lookup}[0xA]		= 0x470;
	$self->{dmc_freq_lookup}[0xB]		= 0x400;
	$self->{dmc_freq_lookup}[0xC]		= 0x350;
	$self->{dmc_freq_lookup}[0xD]		= 0x2A0;
	$self->{dmc_freq_lookup}[0xE]		= 0x240;
	$self->{dmc_freq_lookup}[0xF] 		= 0x1B0;
}

sub init_noise_wavelength_lookup {
	my ($self) = @_;

	$self->{noise_wavelength_lookup} = ();

	$self->{noise_wavelength_lookup}[0x0] 		= 0x004;
	$self->{noise_wavelength_lookup}[0x1]		= 0x008;
	$self->{noise_wavelength_lookup}[0x2]		= 0x010;
	$self->{noise_wavelength_lookup}[0x3]		= 0x020;
	$self->{noise_wavelength_lookup}[0x4]		= 0x040;
	$self->{noise_wavelength_lookup}[0x5]		= 0x060;
	$self->{noise_wavelength_lookup}[0x6]		= 0x080;
	$self->{noise_wavelength_lookup}[0x7]		= 0x0A0;
	$self->{noise_wavelength_lookup}[0x8]		= 0x0CA;
	$self->{noise_wavelength_lookup}[0x9]		= 0x0FE;
	$self->{noise_wavelength_lookup}[0xA]		= 0x17C;
	$self->{noise_wavelength_lookup}[0xB]		= 0x1FC;
	$self->{noise_wavelength_lookup}[0xC]		= 0x2FA;
	$self->{noise_wavelength_lookup}[0xD]		= 0x3F8;
	$self->{noise_wavelength_lookup}[0xE]		= 0x2F2;
	$self->{noise_wavelength_lookup}[0xF]		= 0xFE4;
}

sub init_dac_tables {
	my ($self) = @_;

	my ($value, $ival, $i);
	my $max_sqr = 0;
	my $max_tnd = 0;

	$self->{square_table} = ();
	$self->{square_table}[32*16] = undef;

	$self->{tnd_table} = ();
	$self->{tnd_table}[204*16] = undef;

	for ($i = 0; $i < 32 * 16; $i++) {
		$value  = 95.52 / (8128.0 / ($i/16.0) + 100.0);
		$value *= 0.98411;
		$value *= 50000.0;
		$ival   = int($value);

		$self->{square_table}[$i] = $ival;
		if ($ival > $max_sqr) {
			$max_sqr = $ival;
		} 
	}

	for ($i = 0; $i < 204 * 16; $i++) {
		$value  = 163.67 / (24329.0 / ($i/16.0) + 100.0);
		$value *= 0.98411;
		$value *= 50000.0;
		$ival   = int($value);

		$self->{tnd_table}[$i] = $ival;
		if ($ival > $max_tnd) {
			$max_tnd = $ival;
		}
	}

	$self->{dac_range}		= $max_sqr + $max_tnd;
	$self->{dc_value}		= $self->{dac_range} / 2;
}

1;