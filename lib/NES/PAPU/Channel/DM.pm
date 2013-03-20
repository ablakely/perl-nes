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

package NES::PAPU::Channel::DM;

use strict;
use warnings;

sub new {
	my ($class, $papu) = @_;

	my $self = {
		papu 						=> $papu,

		MODE_NORMAL					=> 0,
		MODE_LOOP					=> 1,
		MODE_IRQ					=> 2,

		is_enabled					=> undef,
		has_sample					=> undef,
		irq_generated				=> 0,

		play_mode					=> undef,
		dma_frequency				=> undef,
		dma_counter					=> undef,
		delta_counter				=> undef,
		play_start_address			=> undef,
		play_address 				=> undef,
		play_length 				=> undef,
		play_length_counter 		=> undef,
		shift_counter 				=> undef,
		reg4012	 					=> undef,
		reg4013 					=> undef,
		sample 						=> undef,
		dac_lsb 					=> undef,
		data 						=> undef
	};

	papu_channeldm_reset();

	return bless($self, $class);
}


sub clock_dmc {
	my ($self) = @_;

	# Only alter DAC value if the sample buffer has data:
	if ($self->{has_sample}) {
		if (($self->{data} & 1) == 0) {
			# Decrement delta:

			if ($self->{delta_counter} > 0) {
				$self->{delta_counter}--;
			}
		} else {
			# Increment delta:
			if ($self->{delta_counter} < 63) {
				$self->{delta_counter}++;
			}
		}

		# Update sample value:
		$self->{sample} = $self->{is_enabled} ? ($self->{delta_counter} << 1) + $self->{dac_lsb} : 0;

		# Update shift register
		$self->{data} >>= 1;
	}

	$self->{dma_counter}--;
	if ($self->{dma_counter} <= 0) {

		# No more sample bits
		$self->{has_sample} 		= 0;
		end_of_sample();
		$self->dma_counter 			= 8;
	}

	if ($self->{irq_generated}) {
		$self->{papu}->{nes}->{cpu}->request_irq($self->{papu}->{nes}->{cpu}->{IRQ_NORMAL});
	}
}

sub end_of_sample {
	my ($self) = @_;

	if ($self->{play_length_counter} == 0 && $self->{play_mode} == $self->{MODE_LOOP}) {
		# Start from beginning of sample:

		$self->{play_address} 			= $self->{play_start_address};
		$self->{play_length_counter}	= $self->{play_length};
	}

	if ($self->{play_length_counter} > 0) {
		# Fetch next sample
		next_sample();

		if ($self->{play_length_counter} == 0) {
			# Last byte of sample fetched, generate IRQ:
			if ($self->{play_mode} == $self->{MODE_IRQ}) {
				# Generate IRQ
				$self->{irq_generated} = 1;
			}
		}
	}
}

sub next_sample {
	my ($self) = @_;

	# Fetch byte:
	$self->{data} 		= $self->{papu}->{nes}->{mmap}->load($self->{play_address});
	$self->{papu}->{nes}->{cpu}->halt_cycles(4);

	$self->{play_length_counter}--;
	$self->{play_address}++;

	if ($self->{play_address} > 0xFFFF) {
		$self->{play_address} = 0x8000;
	}

	$self->{has_sample} = 1;
}

sub write_reg {
	my ($self, $address, $value) = @_;

	if ($address == 0x4010) {
		# Play mode, DMA Frequency
		if (($value >> 6) == 0) {
			$self->{play_mode} = $self->{MODE_NORMAL};
		}
		elsif ((($value >> 6) & 1) == 1) {
			$self->{play_mode} = $self->{MODE_LOOP};
		}
		elsif (($value >> 6) == 2) {
			$self->{play_mode} = $self->{MODE_IRQ};
		}

		if (($value & 0x80) == 0) {
			$self->{irq_generated} = 0;
		}

		$self->{dma_frequency} = $self->{papu}->get_dmc_frequency($value & 0xF);
	}
	elsif ($address == 0x4011) {
		# Delta counter load register

		$self->{delta_counter}	= ($value >> 1) & 63;
		$self->{dac_lsb} 		= $value & 1;
		$self->{sample}			= (($self->{delta_counter} << 1) + $self->{dac_lsb}); # Update sample value
	}
	elsif ($address == 0x4012) {
		# DMA address load register

		$self->{play_start_address} = ($value << 6) | 0x0C000;
		$self->{play_address}       = $self->{play_start_address};
		$self->{reg4012}            = $value;
	}
	elsif ($address == 0x4013) {
		# Length of play code

		$self->{play_length}         = ($value << 4) + 1;
		$self->{play_length_counter} = $self->{play_length};
		$self->{reg4013}             = $value; 
	}
	elsif ($address == 0x4015) {
		# DMC/IRQ Status
		if ((($value >> 4) & 1) == 0) {
			# Disable:
			$self->{play_length_counter} = 0;
		} else {
			# Restart
			$self->{play_address} = $self->{play_start_address};
			$self->{play_length_counter} = $self->{play_length};
		}

		$self->{irq_generated} = 0;
	}
}

sub set_enabled {
	my ($self, $value) = @_;

	if ((!$self->{is_enabled}) && $value) {
		$self->{play_length_counter} = $self->{play_length};
	}

	$self->{is_enabled} = $value;
}

sub get_length_status {
	my ($self) = @_;

	return (($self->{play_length_counter} == 0 || !$self->{is_enabled}) ? 0 : 1);
}

sub get_irq_status {
	my ($self) = @_;

	return ($self->{irq_generated} ? 1 : 0);
}

sub papu_channeldm_reset {
	my ($self) = @_;

	$self->{is_enabled} 			= 0;
	$self->{irq_generated}			= 0;
	$self->{play_mode}				= $self->{MODE_NORMAL};
	$self->{dma_frequency}			= 0;
	$self->{dma_counter}			= 0;
	$self->{delta_counter}			= 0;
	$self->{play_start_address}		= 0;
	$self->{play_address}			= 0;
	$self->{play_length}			= 0;
	$self->{play_length_counter}	= 0;
	$self->{sample}					= 0;
	$self->{dac_lsb}				= 0;
	$self->{shift_counter}			= 0;
	$self->{reg4012}				= 0;
	$self->{reg4013}				= 0;
	$self->{data}					= 0;
}

1;