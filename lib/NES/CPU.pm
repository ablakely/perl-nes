package NES::CPU;

use v5.10.1;
use lib '..';
use strict;
use warnings;
use NES::CPU::OpData;

my $IRQ_NORMAL  = 0;
my $IRQ_NMI		= 1;
my $IRQ_RESET	= 2;

sub new {
	my ($class) = @_;

	my $self = {
		REG_ACC				=> undef,
		REG_X				=> undef,
		REG_Y				=> undef,
		REG_SP				=> undef,
		REG_PC				=> undef,
		REG_PC_NEW			=> undef,
		REG_STATUS			=> undef,
		F_CARRY				=> undef,
		F_DECIMAL			=> undef,
		F_INTERRUPT			=> undef,
		F_INTERRUPT_NEW		=> undef,
		F_OVERFLOW			=> undef,
		F_SIGN				=> undef,
		F_ZERO				=> undef,
		F_NOTUSED			=> undef,
		F_NOTUSED_NEW		=> undef,
		F_BRK				=> undef,
		F_BRK_NEW			=> undef,
		opdata				=> undef,
		cycles_to_halt		=> undef,
		crash				=> undef,
		irq_requested		=> undef,
		irq_type			=> undef
	};

	cpu_reset();

	return bless($self, $class);
}

sub cpu_reset {
	my ($self) = @_;
	$self->{mem}[0x10000] = undef; # Create an array size: 0x10000

	for (my $i = 0; $i < 0x2000; $i++) {
		$self->{mem}[$i] = 0xFF;
	}

	for (my $p = 0; $p < 4; $p++) {
		my $i = $p * 0x800;

		$self->{mem}[$i+0x008]	= 0xF7;
		$self->{mem}[$i+0x009]	= 0xEF;
		$self->{mem}[$i+0x00A]	= 0xDF;
		$self->{mem}[$i+0x00F]	= 0xBF;
	}

	for (my $i = 0x2001; $i < $#$self->{mem}; $i++) {
		$self->{mem}[$i] = 0;
	}

	# CPU Registers:
	$self->{REG_ACC}			= 0;
	$self->{REG_X}				= 0;
	$self->{REG_Y}				= 0;

	# Reset Stack Pointer:
	$self->{REG_SP}				= 0x01FF;

	# Reset Program counter:
	$self->{REG_PC}				= 0x8000 - 1;
	$self->{REG_PC_NEW}			= 0x8000 - 1;

	# Reset Status register:
	$self->{REG_STATUS}			= 0x28;

	set_cpu_status(0x28);

	# Set flags:
	$self->{F_CARRY}			= 0;
	$self->{F_DECIMAL}			= 0;
	$self->{F_INTERRUPT}		= 1;
	$self->{F_INTERRUPT_NEW}	= 1;
	$self->{F_OVERFLOW}			= 0;
	$self->{F_SIGN}				= 0;
	$self->{F_ZERO}				= 1;

	$self->{F_NOTUSED}			= 1;
	$self->{F_NOTUSED_NEW}		= 1;
	$self->{BRK}				= 1;
	$self->{BRK_NEW}			= 1;

	$self->{opdata}				= NES::CPU::OpData->new();
	$self->{cycles_to_halt}		= 0;

	# Reset crash flag:
	$self->{crash}				= 0;

	# Interrupt notification:
	$self->{irq_requested}		= 0;
	$self->{irq_type}			= undef;
}

# Emulates a single CPU instruction, returns the number of cycles
sub emulate {
	my ($self) = @_;
	my ($temp, $add);

	if ($self->{irq_requested}) {
		$temp = ($self->{F_CARRY}) 			|
			(($self->{F_ZERO}==0?1:0) << 1) |
			($self->{F_INTERRUPT}     << 2)	|
			($self->{F_DECIMAL}       << 3) |
			($self->{F_BRK}           << 4) |
			($self->{F_NOTUSED}       << 5) |
			($self->{F_OVERFLOW}      << 6) |
			($self->{F_SIGN}          << 7) ;

		$self->{REG_PC_NEW} 			= $self->{REG_PC};
		$self->{F_INTERRUPT_NEW}		= $self->{INTERRUPT};

		for ($self->{irq_type}) {
			if (0) {
				# Normal IRQ:
				if ($self->{F_INTERRUPT} != 0) {
					last;
				}

				do_irq($temp);
				last;
			}

			if (1) {
				# Nonmaskable Interrupt
				do_nonmaskable_interrupt($temp);
				last;
			}

			if (2) {
				# Reset:
				do_reset_interrupt();
				last;
			}
		}

		$self->{REG_PC}		= $self->{REG_PC_NEW};
		$self->{F_INTERRUPT}	= $self->{F_INTERRUPT_NEW};
		$self->{F_BRK}		= $self->{F_BRK_NEW};
		$self->{irq_requested}	= 0;
	}

	my $opinf = @{$self->{opdata}}[$self::NES::MMap->{load}($self->{REG_PC} + 1) ];
	my $cycle_count = ($opinf >> 24);
	my $cycle_add   = 0;

	# Find address mode:
	my $addr_mode = ($opinf >> 8) & 0xFF;

	# Increment PC by number of op bytes
	my $opaddr = $self->{REG_PC};
	$self->{REG_PC} += (($opinf >> 16) & 0xFF);

	my $addr = 0;
	for ($addr_mode) {
		if (0) {
			# Zero Page mode.  Use the address given after the opcode,
			# but without high byte.
			$addr = load($opaddr+2);
			last;
		}
		
		if (1) {
			# Relative Mode
			$addr = load($opaddr+2);

			if ($addr < 0x80) {
				$addr += $self->{REG_PC};
			} else {
				$addr += $self->{REG_PC} - 256;
			}
			last;
		}
		
		if (2) {
			# Ignore. Address is implied in instruction.
			last;
		}

		if (3) {
			# Absolute mode.  Use the two bytes following the opcode as
			# an address.
			$addr = load_16bit($opaddr+2);
			last;
		}

		if (4) {
			# Accumulator mode.  The address is in the accumlator
			# register.
			$addr = $self->{REG_ACC};
			last;
		}

		if (5) {
			# Immediate mode.  The value is given after the opcode.
			$addr = $self->{REG_PC};
			last;
		}

		if (6) {
			# Zero Page Indexed mode, X as index.  Use the address given
			# after the opcode, then add the X register to it to get the final address.
			$addr = (load($opaddr+2)+$self->{REG_X})&0xFF;
			last;

		}

		if (7) {
			# Zero Page Indexed mode, Y as index.  Use the address given
			# after the opcode, then add the Y register to it to get the final address.
			$addr = (load($opaddr+2)+$self->{REG_Y})&0xFF;
			last;
		}

		if (8) {
			# Absolute Indexed Mode, X as index.  Same as zero page indexed,
			# but with the high byte.
			$addr = load_16bit($opaddr+2);

			if (($addr & 0xFF00) != (($addr + $self->{REG_X})&0xFF00)) {
				$cycle_add = 1;
			}

			$addr += $self->{REG_X};
			last;
		}

		if (9) {
			# Absolute Indexed Mode, Y as index.  Same as zero page indexed,
			# but with the high byte.
			$addr = load_16bit($opaddr+2);

			if (($addr & 0xFF00) != (($addr + $self->{REG_Y})&0xFF00)) {
				$cycle_add = 1;
			}

			$addr += $self->{REG_Y};
			last;
		}

		if (10) {
			# Pre-indexed Indirect mode.  Find the 16-bit address starting
			# at the given location plus the current X register.  The value
			# is the content of that address.
			$addr = load($opaddr+2);

			if (($addr&0xFF00) != (($addr+$self->{REG_X})&0xFF00)) {
				$cycle_add = 1;
			}

			$addr += $self->{REG_X};
			$addr &= 0xFF;
			$addr = load_16bit($addr);

			last;
		}

		if (11) {
			# Post-indexed Indirect mode.  Find the 16-bit address contained
			# in the given location (and the one following).  Add to that
			# address the contents of the Y register.  Fetch the value stored
			# at that address.
			$addr = load_16bit(load($opaddr+2));

			if (($addr&0xFF00) != (($addr+$self->{REG_Y})&0xFF00)) {
				$cycle_add = 1;
			}

			$addr += $self->{REG_Y};
			last;
		}

		if (12) {
			# Indrect Absolute mode.  Find the 16-bit address contained at
			# the given location.
			$addr = load_16bit($opaddr+2); # Find op

			if ($addr < 0x1FFF) {
				$addr = @{$self->{mem}}[$addr] + (@{$self->{mem}}[($addr & 0xFF00) | ((($addr & 0xFF) + 1) & 0xFF)] << 8); # Read from addr given in op
			}
			else
			{
				$addr = $self::NES::MMap->{load}($addr) + ($self::NES::MMap->{load}(($addr & 0xFF00) | ((($addr & 0xFF) + 1) & 0xFF)) << 8);
			}

			last;
		}
	}

	# Wrap arround for address above 0xFFFF:
	$addr &= 0xFFFF;

	# -------------------------------------------------------------------------------------
	#  Decode & execute instruction:
	# -------------------------------------------------------------------------------------

	for ($opinf & 0xFF) {
		when (0) {
			# ADC instruction

			$temp = $self->{REG_ACC} + load($addr) + $self->{F_CARRY};
			$self->{F_OVERFLOW}	= ((!((($self->{REG_ACC} ^ load($addr)) & 0x80) != 0) && ((($self->{REG_ACC} ^ $temp) & 0x80)) != 0) ? 1:0);
			$self->{F_CARRY}		= ($temp > 255 ? 1:0);
			$self->{F_SIGN}		= ($temp >> 7) & 1;
			$self->{F_ZERO}		= $temp & 0xFF;
			$self->{REG_ACC}		= ($temp & 255);
			$cycle_count           += $cycle_add;

			break;
		}

		when (1) {
			# AND instruction

			# AND memory with accumulator.
			$self->{REG_ACC}		= $self->{REG_ACC} & load($addr);
			$self->{F_SIGN}		= ($self->{REG_ACC} >> 7) & 1;
			$self->{F_ZERO}		= $self->{REG_ACC};

			if ($addr_mode != 11) {
				$cycle_count += $cycle_add;
			}

			break;
		}

		when (2) {
			# ASL instruction

			# Shift left one bit
			if ($addr_mode == 4) {
				$self->{F_CARRY}		= ($self->{REG_ACC} >> 7) & 1;
				$self->{REG_ACC}		= ($self->{REG_ACC} << 1) & 255;
				$self->{F_SIGN}		= ($self->{REG_ACC} >> 7) & 1;
				$self->{F_ZERO}		= $self->{REG_ACC};
			} else {
				$temp = load($addr);
				$self->{F_CARRY}		= ($temp >> 7) & 1;
				
				$temp = ($temp << 1) & 255;
				$self->{F_SIGN}		= ($temp >> 7) & 1;
				$self->{F_ZERO}		= $temp;

				cpu_write($addr, $temp);
			}

			break;
		}

		when (3) {
			# BCC instruction

			# Branch on carry clear
			if ($self->{F_CARRY} == 0) {
				$cycle_count += (($opaddr & 0xFF00) != ($addr & 0xFF00) ? 2:1);
				$self->{REG_PC} = $addr;
			}

			break;
		}

		when (4) {
			# BCS instruction

			# Branch on carry set
			if ($self->{F_CARRY} == 1) {
				$cycle_count += (($opaddr & 0xFF00) != ($addr & 0xFF00) ? 2:1);
				$self->{REG_PC} = $addr;
			}

			break;
		}

		when (5) {
			# BEQ instruction

			# Branch on zero
			if ($self->{F_ZERO} == 0) {
				$cycle_count += (($opaddr & 0xFF00) != ($addr & 0xFF00) ? 2:1);
				$self->{REG_PC} = $addr;
			}

			break;
		}

		when (6) {
			# BIT Instruction

			$temp = load($addr);
			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_OVERFLOW}	= ($temp >> 6)&1;

			$temp 		      &= $self->{REG_ACC};
			$self->{F_ZERO}		= $temp;

			break;
		}

		when (7) {
			# BMI instruction

			# Branch on negative result
			if ($self->{F_SIGN} == 1) {
				$cycle_count++;
				$self->{REG_PC} = $addr;
			}

			break;
		}

		when (8) {
			# BNE Instruction

			# Branch on not zero
			if ($self->{F_ZERO} != 0) {
				$cycle_count += (($opaddr&0xFF00) != ($addr&0xFF00)?2:1);
				$self->{REG_PC}	= $addr;
			}

			break;
		}

		when (9) {
			# BPL Instruction

			# Branch on positive result
			if ($self->{F_SIGN} == 0) {
				$cycle_count += (($opaddr&0xFF00)!=($addr&0xFF00)?2:1);
				$self->{REG_PC} = $addr;
			}

			break;
		}

		when (10) {
			# BRK Instruction

			$self->{REG_PC} += 2;
			cpu_push(($self->{REG_PC}>>{8})&255);
			cpu_push($self->{REG_PC}&255);
			$self->{F_BRK}	= 1;

			cpu_push(($self->{F_CARRY})|(($self->{F_ZERO}==0?1:0)<<1)|($self->{F_INTERRUPT}<<2)|($self->{F_DECIMAL}<<3)|
				 ($self->{F_BRK}<<4)|($self->{F_NOTUSED}<<5)|($self->{F_OVERFLOW}<<6)|($self->{F_SIGN}<<7));

			$self->{F_INTERRUPT}	= 1;
			$self->{REG_PC}		= load_16bit(0xFFFE);
			$self->{REG_PC}--;

			break;
		}

		when (11) {
			#BVC Instruction

			# Branch on overflow clear
			if ($self->{F_OVERFLOW} == 0) {
				$cycle_count += (($opaddr&0xFF00)!=($addr&0xFF00)?2:1);
				$self->{REG_PC} = $addr;
			}

			break;
		}

		when (12) {
			# BVS Instruction
			# Branch on overflow set

			if ($self->{F_OVERFLOW} == 1) {
				$cycle_count += (($opaddr&0xFF00)!=($addr&0xFF00)?2:1);
				$self->{REG_PC} = $addr;
			}

			break;
		}

		when (13) {
			# CLC Instruction
			# Clear carry flag

			$self->{F_CARRY} = 0;
			break;
		}

		when (14) {
			# CLD Instruction
			# Clear decimal flag

			$self->{F_DECIMAL} = 0;
			break;
		}

		when (15) {
			# CLI Instruction
			# Clear interrupt flag

			$self->{F_INTERRUPT} = 0;
			break;
		}

		when (16) {
			# CLV Instruction
			# Clear overflow flag

			$self->{F_OVERFLOW} = 0;
			break;
		}

		when (17) {
			# CMP Instruction
			# Compare memory and accumulator

			$temp = $self->{REG_ACC} - load($addr);
			$self->{F_CARRY}		= ($temp >= 0?1:0);
			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp & 0xFF;

			$cycle_count 	       += $cycle_add;
			break;
		}

		when (18) {
			# CPX Instruction
			# Compare memory and index X

			$temp = $self->{REG_X} - load($addr);
			$self->{F_CARRY}		= ($temp >= 0?1:0);
			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp & 0xFF;
			break;
		}

		when (19) {
			# CPY Instruction
			# Compare memory and index Y

			$temp = $self->{REG_Y} - load($addr);
			$self->{F_CARRY}		= ($temp >= 0?1:0);
			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp & 0xFF;
			break;
		}

		when (20) {
			# DEC Instruction
			# Decrement memory by one

			$temp = (load($addr)-1)&0xFF;
			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp;

			cpu_write($addr, $temp);
			break;
		}

		when (21) {
			# DEX Instruction
			# Decrement index X by one

			$self->{REG_X}		= ($self->{REG_X}-1)&0xFF;
			$self->{F_SIGN}		= ($self->{REG_X} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_X};

			break;
		}

		when (22) {
			# DEY Instruction
			# Decrement index Y by one

			$self->{REG_Y}		= ($self->{REG_Y}-1)&0xFF;
			$self->{F_SIGN}		= ($self->{REG_Y} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_Y};
			break;
		}

		when (23) {
			# EOR Instruction
			# XOR Memory with accumulator, store in accumulator

			$self->{REG_ACC}		= (load($addr)^$self->{REG_ACC})&0xFF;
			$self->{F_SIGN}		= ($self->{REG_ACC} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_ACC};

			$cycle_count	       += $cycle_add;
			break;
		}

		when (24) {
			# INC Instruction
			# Increment memory by one

			$temp = (load($addr)+1)&0xFF;
			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp;

			cpu_write($addr, $temp & 0xFF);
			break;
		}

		when (25) {
			# INX Instruction
			# Increment index X by one

			$self->{REG_X}		= ($self->{REG_X}+1)&0xFF;
			$self->{F_SIGN}		= ($self->{REG_X} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_X};

			break;
		}

		when (26) {
			# INY Instruction
			# Increment index Y by one

			$self->{REG_Y}		= ($self->{REG_Y}+1)&0xFF;
			$self->{F_SIGN}		= ($self->{REG_Y} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_Y};
			break;
		}

		when (27) {
			# JMP Instruction
			# Jump to new location

			$self->{REG_PC} = $addr - 1;
			break;
		}

		when (28) {
			# JSR Instruction
			# Jump to new location, saving return address

			# Push return address on stac
			cpu_push(($self->{REG_PC} >> 8)&255);
			cpu_push($self->{REG_PC}&255);
			$self->{REG_PC} = $addr-1;
			break;
		}

		when (29) {
			# LDA Instruction
			# Load accumulator with memory

			$self->{REG_ACC}		= load($addr);
			$self->{F_SIGN}		= ($self->{REG_ACC} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_ACC};

			$cycle_count           += $cycle_add;
			break;
		}

		when (30) {
			# LDX Instruction
			# Load index X with memory

			$self->{REG_X}		= load($addr);
			$self->{F_SIGN}		= ($self->{REG_X} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_X};

			$cycle_count           += $cycle_add;
			break;
		}

		when (31) {
			# LDY Instruction
			# Load index Y with memory

			$self->{REG_Y}		= load($addr);
			$self->{F_SIGN}		= ($self->{REG_Y} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_Y};

			$cycle_count	       += $cycle_add;
			break;
		}

		when (32) {
			# LSR Instruction
			# Shift right one bitt

			if ($addr_mode == 4) {
				$temp 			= ($self->{REG_ACC} & 0xFF);
				$self->{F_CARRY}		= $temp & 1;
				$temp 		      >>= 1;
				$self->{REG_ACC}		= $temp;
			} else {
				$temp 			= load($addr) & 0xFF;
				$self->{F_CARRY} 		= $temp & 1;
				$temp                 >>= 1;

				cpu_write($addr, $temp);
			}

			$self->{F_SIGN}	= 0;
			$self->{F_ZERO}	= $temp;
			break;
		}

		when (33) {
			# NOP Instruction
			# No operation -- Ignore.
			break;
		}

		when (34) {
			# ORA Instruction
			# OR memory with accumulator, store in accumulator.
			
			$temp			= (load($addr) | $self->{REG_ACC})&255;
			$self->{F_SIGN}		= ($temp >> 7) & 1;
			$self->{F_ZERO}		= $temp;
			$self->{REG_ACC}		= $temp;

			if ($addr_mode != 11) {
				$cycle_count += $cycle_add;
			}

			break;
		}

		when (35) {
			# PHA Instruction
			# Push accumulator on stack

			cpu_push($self->{REG_ACC});
			break;
		}

		when (36) {
			# PHP Instruction
			# Push processor status on stack

			$self->{F_BRK}	= 1;
			cpu_push(($self->{F_CARRY})|(($self->{F_ZERO}==0?1:0)<<1)|($self->{F_INTERRUPT}<<2)|($self->{F_DECIMAL}<<3)|
				 ($self->{F_BRK}<<4)|($self->{F_NOTUSED}<<5)|($self->{F_OVERFLOW}<<6)|($self->{F_SIGN}<<7));

			break;
		}

		when (37) {
			# PLA Instruction
			# Push accumulator from stack

			$self->{REG_ACC}		= cpu_pull();
			$self->{F_SIGN}		= ($self->{REG_ACC} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_ACC};
			break;
		}

		when (38) {
			# PLP Instruction
			# Pull processor status from stack

			$temp = cpu_pull();
			$self->{F_CARRY}			= ($temp     ) &1;
			$self->{F_ZERO}			= (((($temp >> 1) &1) == 1) ? 0:1);
			$self->{F_INTERRUPT}		= ($temp >> 2) &1;
			$self->{F_DECIMAL}		= ($temp >> 3) &1;
			$self->{F_BRK}			= ($temp >> 4) &1;
			$self->{F_NOTUSED}		= ($temp >> 5) &1;
			$self->{F_OVERFLOW}		= ($temp >> 6) &1;
			$self->{F_SIGN}			= ($temp >> 7) &1;

			$self->{F_NOTUSED}		= 1;
			break;
		}

		when (39) {
			# ROL Instruction
			# Rotate one bit left

			if ($addr_mode == 4) {
				$temp		= $self->{REG_ACC};
				$add		= $self->{F_CARRY};
				$self->{F_CARRY}	= ($temp >> 7)&1;
				$self->{REG_ACC}	= $temp;
			} else {
				$temp		= load($addr);
				$add		= $self->{F_CARRY};
				$self->{F_CARRY}	= ($temp >> 7)&1;
				$temp		= (($temp << 1)&0xFF)+$add;

				cpu_write($addr, $temp);
			}

			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp;
			break;
		}

		when (40) {
			# ROR Instruction
			# Rotate one bit right

			if ($addr_mode == 4) {
				$add		= $self->{F_CARRY} << 7;
				$self->{F_CARRY}	= $self->{REG_ACC}&1;
				$temp		= ($self->{REG_ACC}>>{1})+$add;
				$self->{REG_ACC}	= $temp;
			} else {
				$temp		= load($addr);
				$add		= $self->{F_CARRY} << 7;
				$self->{F_CARRY}	= $temp&1;
				$temp		= ($temp >> 1)+$add;

				cpu_write($addr, $temp);
			}

			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp;
			break;
		}

		when (41) {
			# RTI Instruction
			# Return from interrupt.  Pull status and PC from stack.

			$temp = cpu_pull();
			$self->{F_CARRY}		= ($temp     )&1;
			$self->{F_ZERO}		= (($temp >>{1})&1) == 0?1:0;
			$self->{F_INTERRUPT}	= ($temp >> 2)&1;
			$self->{F_DECIMAL}	= ($temp >> 3)&1;
			$self->{F_BRK}		= ($temp >> 4)&1;
			$self->{F_NOTUSED}	= ($temp >> 5)&1;
			$self->{F_OVERFLOW}	= ($temp >> 6)&1;
			$self->{F_SIGN}		= ($temp >> 7)&1;

			$self->{REG_PC}		= cpu_pull();
			$self->{REG_PC}	       += (cpu_pull() << 8);

			if ($self->{REG_PC} == 0xFFFF) {
				return;
			}

			$self->{REG_PC}--;
			$self->{F_NOTUSED} = 1;
			break;
		}

		when (42) {
			# RTS Instruction
			# Return from subroutine.  Pull PC from stack.

			$self->{REG_PC}	= cpu_pull();
			$self->{REG_PC}  += (cpu_pull() << 8);

			if ($self->{REG_PC} == 0xFFFF) {
				return;
			}

			break;
		}

		when (43) {
			# SBC Instruction

			$temp			= $self->{REG_ACC} - load($addr) - (1 - $self->{F_CARRY});
			$self->{F_SIGN}		= ($temp >> 7)&1;
			$self->{F_ZERO}		= $temp & 0xFF;
			$self->{F_OVERFLOW}	= ((($self->{REG_ACC} ^ $temp) &0x80) !=0 && (($self->{REG_ACC} ^ load($addr)) &0x80)!=0?1:0);
			$self->{F_CARRY}		= ($temp<0?0:1);
			$self->{REG_ACC}		= ($temp&0xFF);

			if ($addr_mode != 11) {
				$cycle_count += $cycle_add;
			}

			break;
		}

		when (44) {
			# SEC Instruction
			# Set carry flag

			$self->{F_CARRY} = 1;
			break;
		}

		when (45) {
			# SED Instruction
			# Set decimal mode

			$self->{F_DECIMAL} = 1;
			break;
		}

		when (46) {
			# SEI Instruction
			# Set interrupt disable status

			$self->{F_INTERRUPT} = 1;
			break;
		}

		when (47) {
			# STA Instruction
			# Store accumulator in memory

			cpu_write($addr, $self->{REG_ACC});
			break;
		}

		when (48) {
			# STX Instruction
			# Store index X in memory

			cpu_write($addr, $self->{REG_X});
			break;
		}

		when (49) {
			# STY Instruction
			# Store index Y in memory

			cpu_write($addr, $self->{REG_Y});
			break;
		}

		when (50) {
			# TAX Instruction
			# Transfer accumulator to index X

			$self->{REG_X}		= $self->{REG_ACC};
			$self->{F_SGIN}		= ($self->{REG_ACC} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_ACC};
			break;
		}

		when (51) {
			# TAY Instruction
			# Transfer accumulator to index Y

			$self->{REG_Y}		= $self->{REG_ACC};
			$self->{F_SIGN}		= ($self->{REG_ACC} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_ACC};
			break;
		}

		when (52) {
			# TSX Instruction
			# Transfer stack pointer to index X

			$self->{REG_X}		= ($self->{REG_SP} - 0x0100);
			$self->{F_SIGN}		= ($self->{REG_SP} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_X};
			break;
		}

		when (53) {
			# TXA Instruction
			# Transfer index X to accumulator

			$self->{REG_ACC}		= $self->{REG_X};
			$self->{F_SIGN}		= ($self->{REG_X} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_X};

			break;
		}

		when (54) {
			# TXS Instruction
			# Transfer index X to stack pointer

			$self->{REG_SP}		= ($self->{REG_X} + 0x0100);
			stack_wrap();

			break;
		}

		when (55) {
			# TYA Instruction
			# Transfer index Y to accumulator

			$self->{REG_ACC}		= $self->{REG_Y};
			$self->{F_SIGN}		= ($self->{REG_Y} >> 7)&1;
			$self->{F_ZERO}		= $self->{REG_Y};
			break;
		}

		default {
			# Unknown Instruction -- Crash

			$self::NES->{stop}();
			$self::NES->{crash_message} = "Game crashed!  Invalid opcode at address: \$".$opaddr;

			break;
		}

	}

	return $cycle_count;
}

sub load {
	my ($self, $addr)  = @_;

	if ($addr < 0x2000) {
		return @{$self->{mem}}[$addr & 0x7FF];
	} else {
		return $self::NES::MMap->{load}($addr);
	}
}

sub load_16bit {
	my ($self, $addr) = @_;

	if ($addr < 0x1FFF) {
		return @{$self->{mem}}[$addr & 0x7FF] | (@{$self->{mem}}[($addr+1)&0x7FF] << 8);
	} else {
		return $self::NES::MMap->{load}($addr) | ($self::NES::MMap->{load}($addr+1) << 8);
	}
}

sub cpu_write {
	my ($self, $addr, $val) = @_;

	if ($addr < 0x2000) {
		@{$self->{mem}}[$addr & 0x7FF] = $val;
	} else {
		$self::NES::MMap->{mem_write}($addr, $val);
	}
}

sub request_irq {
	my ($self, $type) = @_;

	if ($self->{irq_requested}) {
		if ($type == $IRQ_NORMAL) {
			return;
		}
	}

	$self->{irq_requested}	= 1;
	$self->{irq_type}		= $type;
}

sub cpu_push {
	my ($self, $value) = @_;

	$self::NES::MMap->{mem_write}($self->{REG_SP}, $value);

	$self->{REG_SP}--;
	$self->{REG_SP} = 0x0100 | ($self->{REG_SP}&0xFF);
}

sub stack_wrap {
	my ($self) = @_;

	$self->{REG_SP} = 0x0100 | ($self->{REG_SP}&0xFF);
}

sub cpu_pull {
	my ($self) = @_;

	$self->{REG_SP}++;
	$self->{REG_SP}	= 0x0100 | ($self->{REG_SP} & 0xFF);

	return $self::NES::MMap->{load}($self->{REG_SP});
}

sub page_crossed {
	my ($self, $addr1, $addr2) = @_;

	return (($addr1&0xFF00) != ($addr2&0xFF00));
}

sub halt_cycles {
	my ($self, $cycles) = @_;

	$self->{cycles_to_halt} += $cycles;
}

sub do_nonmaskable_interrupt {
	my ($self, $status) = @_;

	# Check wheter VBlank Interrupts are enabled
	if (($self::NES::MMap->{load}(0x2000) & 128) != 0) {
		$self->{REG_PC_NEW}++;
		cpu_push(($self->{REG_PC_NEW} >> 8) & 0xFF);
		cpu_push($self->{REG_PC_NEW} & 0xFF);
		cpu_push($status);

		$self->{REG_PC_NEW} = $self::NES::MMap->{load}(0xFFFA) | ($self::NES::MMap->{load}(0xFFFB) << 8);
		$self->{REG_PC_NEW}--;
	}
}

sub do_reset_interrupt {
	my ($self) = @_;

	$self->{REG_PC_NEW}	= $self::NES::MMap->{load}(0xFFFC) | ($self::NES::MMap->{load}(0xFFFD) << 8);
	$self->{REG_PC_NEW}--;
}

sub do_irq {
	my ($self, $status) = @_;

	$self->{REG_PC_NEW}++;
	cpu_push(($self->{REG_PC_NEW} >> 8) & 0xFF);
	cpu_push($self->{REG_PC_NEW} & 0xFF);
	cpu_push($status);

	$self->{F_INTERRUPT_NEW}		= 1;
	$self->{F_BRK_NEW}		= 0;

	$self->{REG_PC_NEW}		= $self::NES::MMap->{load}(0xFFFE) | ($self::NES::MMap->{load}(0xFFFF) << 8);
	$self->{REG_PC_NEW}--;
}

sub get_status {
	my ($self) = @_;

	return 	($self->{F_CARRY})		|
		($self->{F_ZERO} 		<< 1)	|
		($self->{F_INTERRUPT}	<< 2)	|
		($self->{F_DECIMAL}	<< 3)	|
		($self->{F_BRK}		<< 4)	|
		($self->{F_NOTUSED}	<< 5)	|
		($self->{F_OVERFLOW}	<< 6)	|
		($self->{F_SIGN}		<< 7)   ;
}

sub set_status {
	my ($self, $st) = @_;

	$self->{F_CARRY}			= ($st     ) &1;
	$self->{F_ZERO}			= ($st >> 1) &1;
	$self->{F_INTERRUPT}		= ($st >> 2) &1;
	$self->{F_DECIMAL}		= ($st >> 3) &1;
	$self->{F_BRK}			= ($st >> 4) &1;
	$self->{F_NOTUSED}		= ($st >> 5) &1;
	$self->{F_OVERFLOW}		= ($st >> 6) &1;
	$self->{F_SIGN}			= ($st >> 7) &1;
}

1;
