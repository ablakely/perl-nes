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

package NES::PAPU::Channel::Noise;

use strict;
use warnings;

sub new {
	my ($class, $papu) = @_;

	my $self = {
		papu 						=> $papu,
		is_enabled					=> undef,
		env_decay_disable 			=> undef,
		env_decay_loop_enable		=> undef,
		length_counter_enable		=> undef,
		env_reset					=> undef,
		shift_now 					=> undef,

		length_counter 				=> undef,
		prog_timer_count			=> undef,
		prog_timer_max 				=> undef,
		env_decay_rate 				=> undef,
		env_decay_counter			=> undef,
		env_volume					=> undef,
		master_volume				=> undef,
		shift_reg					=> 1 << 14,
		random_bit 					=> undef,
		random_mode 				=> undef,
		sample_value				=> undef,
		acc_value					=> 0,
		acc_count 					=> 1,
		tmp							=> 0
	};

	papu_channel_noise_reset();

	return bless($self, $class);
}

sub papu_channel_noise_reset {
	my ($self) = @_;

	$self->{prog_timer_count}			= 0;
	$self->{prog_timer_max}				= 0;
	$self->{is_enabled}					= 0;
	$self->{length_counter}				= 0;
	$self->{length_counter_enable}		= 0;
	$self->{env_decay_disable}			= 0;
	$self->{env_decay_loop_enable}		= 0;
	$self->{shift_now}					= 0;
	$self->{env_decay_rate}				= 0;
	$self->{env_decay_counter}			= 0;
	$self->{env_volume}					= 0;
	$self->{master_volume}				= 0;
	$self->{shift_reg}					= 1;
	$self->{random_bit}					= 0;
	$self->{random_mode}				= 0;
	$self->{sample_value}				= 0;
	$self->{tmp}						= 0;
}

sub clock_length_counter {
	my ($self) = @_;

	if ($self->{length_counter_enable} && $self->{length_counter} > 0) {
		$self->{length_counter}--;

		if ($self->{length_counter} == 0) {
			update_sample_value();
		}
	}
}

sub clock_env_decay {
	my ($self) = @_;

	if ($self->{env_reset}) {
		# Reset envelope:

		$self->{env_reset}			= 0;
		$self->{env_decay_counter}	= $self->{env_decay_rate} + 1;
		$self->{env_volume}			= 0xF;
	}
	elsif (--$self->{env_decay_counter} <= 0) {
		# Normal handling:

		$self->{env_decay_counter} = $self->{env_decay_rate} + 1;
		if ($self->{env_volume} > 0) {
			$self->{env_volume}--;
		} else {
			$self->{env_volume} = $self->{env_decay_loop_enable} ? 0xF : 0;
		}
	}

	$self->{master_volume} = $self->{env_decay_disable} ? $self->{env_decay_rate} : $self->{env_volume};
	update_sample_value();
}

sub update_sample_value {
	my ($self) = @_;

	if ($self->{is_enabled} && $self->{length_counter} > 0) {
		$self->{sample_value} = $self->{random_bit} * $self->{master_volume};
	}
}

sub write_reg {
	my ($self, $address, $value) = @_;

	if ($address == 0x400C) {
		# Volume/Envelope decay:

		$self->{env_decay_disable}			= (($value & 0x10) != 0);
		$self->{env_decay_rate}				= $value & 0xF;
		$self->{env_decay_loop_enable}		= (($value & 0x20) != 0);
		$self->{length_counter_enable}		= (($value & 0x20) == 0);
		$self->{master_volume}				= $self->{env_decay_disable} ? $self->{env_decay_rate} : $self->{env_volume};
	}
	elsif ($address == 0x400E) {
		# Programmable timer:

		$self->{prog_timer_max}				= $self->{papu}->get_noise_wavelength($value & 0xF);
		$self->{random_mode}				= $value >> 7;
	}
	elsif ($address == 0x400F) {
		# Length counter

		$self->{length_counter}				= $self->{papu}->get_length_max($value & 248);
		$self->{env_reset}					= 1;
	}
}

sub set_enabled {
	my ($self, $value) = @_;

	$self->{is_enabled} = $value;
	if (!$value) {
		$self->{length_counter}				= 0;
	}

	update_sample_value();
}

sub get_length_status {
	my ($self) = @_;

	return (($self->{length_counter} == 0 || !$self->{is_enabled}) ? 0 : 1);
}

1;