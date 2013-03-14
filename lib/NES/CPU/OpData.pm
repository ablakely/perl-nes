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

package NES::CPU::OpData;

use strict;
use warnings;

sub new {
	my ($class) = @_;
	my $self    = {
		opdata			=> [],
		cyc_table		=> [
			7,6,2,8,3,3,5,5,3,2,2,2,4,4,6,6,	# 0x00
			2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,	# 0x10
			6,6,2,8,3,3,5,5,4,2,2,2,4,4,6,6,	# 0x20
			2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,	# 0x30
			6,6,2,8,3,3,5,5,3,2,2,2,3,4,6,6,	# 0x40
			2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,	# 0x50
			6,6,2,8,3,3,5,5,4,2,2,2,5,4,6,6,	# 0x60
			2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,	# 0x70
			2,6,2,6,3,3,3,2,2,2,2,4,4,4,4,4,	# 0x80
			2,6,2,6,4,4,4,4,2,5,2,5,5,5,5,5,	# 0x90
			2,6,2,6,3,3,3,3,2,2,2,2,4,4,4,4,	# 0xA0
			2,5,2,5,4,4,4,4,2,4,2,4,4,4,4,4,	# 0xB0
			2,6,2,8,3,3,5,5,2,2,2,2,4,4,6,6,	# 0xC0
			2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,	# 0xD0
			2,6,3,8,3,3,5,5,2,2,2,2,4,4,6,6,	# 0xE0
			2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7		# 0xF0
		],

		instname		=> ['ADC', 'AND', 'ASL', 'BCC', 'BCS', 'BEQ', 'BIT', 'BMI',
					    'BMI', 'BNE', 'BPL', 'BRK', 'BVC', 'BVS', 'CLC', 'CLD',
					    'CLI', 'CLV', 'CMP', 'CPX', 'CPY', 'DEC', 'DEX', 'DEY',
					    'EOR', 'INC', 'INY', 'JMP', 'JSR', 'LDA', 'LDX', 'LDY',
					    'LSR', 'NOP', 'ORA', 'PHA', 'PHP', 'PLA', 'PLP'. 'ROL',
					    'ROR', 'RTI', 'RTS', 'SBC', 'SEC', 'SED', 'SEI', 'STA',
					    'STX', 'STY', 'TAX', 'TAY', 'TSX', 'TXA', 'TXS', 'TYA'],

		addr_desc		=> [
					"Zero Page		",
					"Relative		",
					"Implied		",
					"Absolute		",
					"Accumulator		",
					"Immediate		",
					"Zero Page,X		",
					"Zero Page,Y		",
					"Absolute,X		",
					"Absolute,Y		",
					"Preindexed Indirect	",
					"Postindexed Indirect	",
					"Indirect Absolute	"],

		INS_ADC			=> 0,
		INS_AND			=> 1,
		INS_ASL			=> 2,

		INS_BCC			=> 3,
		INS_BCS			=> 4,
		INS_BEQ			=> 5,
		INS_BIT			=> 6,
		INS_BMI			=> 7,
		INS_BNE			=> 8,
		INS_BPL			=> 9,
		INS_BRK			=> 10,
		INS_BVC			=> 11,
		INS_BVS			=> 12,

		INS_CLC			=> 13,
		INS_CLD			=> 14,
		INS_CLI			=> 15,
		INS_CLV			=> 16,
		INS_CMP			=> 17,
		INS_CPX			=> 18,
		INS_CPY			=> 19,

		INS_DEC			=> 20,
		INS_DEX			=> 21,
		INS_DEY			=> 22,

		INS_EOR			=> 23,

		INS_INC			=> 24,
		INS_INX			=> 25,
		INS_INY			=> 26,

		INS_JMP			=> 27,
		INS_JSR			=> 28,

		INS_LDA			=> 29,
		INS_LDX			=> 30,
		INS_LDY			=> 31,
		INS_LSR			=> 32,

		INS_NOP			=> 33,

		INS_ORA			=> 34,

		INS_PHA			=> 35,
		INS_PHP			=> 36,
		INS_PLA			=> 37,
		INS_PLP			=> 38,

		INS_ROL			=> 39,
		INS_ROR			=> 40,
		INS_RTI			=> 41,
		INS_RTS			=> 42,

		INS_SBC			=> 43,
		INS_SEC			=> 44,
		INS_SED			=> 45,
		INS_SEI			=> 46,
		INS_STA			=> 47,
		INS_STX			=> 48,
		INS_STY			=> 49,

		INS_TAX			=> 50,
		INS_TAY			=> 51,
		INS_TSX			=> 52,
		INS_TXA			=> 53,
		INS_TXS			=> 54,
		INS_TYA			=> 55,

		INS_DUMMY		=> 56,			# Dummy instruction used for 'halting' the processor some cycles

		# Addressing modes:
		ADDR_ZP			=> 0,
		ADDR_REL		=> 1,
		ADDR_IMP		=> 2,
		ADDR_ABS		=> 3,
		ADDR_ACC		=> 4,
		ADDR_IMM		=> 5,
		ADDR_ZPX		=> 6,
		ADDR_ZPY		=> 7,
		ADDR_ABSX		=> 8,
		ADDR_ABSY		=> 9,
		ADDR_PREIDXIND		=> 10,
		ADDR_POSTIDXIND		=> 11,
		ADDR_INDABS		=> 12
	};

	for (my $i = 0; $i < 256; $i++) {
		$self->{opdata}[$i] = 0xFF;
	}

	# ADC
	set_op($self->{INS_ADC}, 0x69, $self->{ADDR_IMM}       , 2, 2);
	set_op($self->{INS_ADC}, 0x65, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_ADC}, 0x75, $self->{ADDR_ZPX}       , 2, 4);
	set_op($self->{INS_ADC}, 0x6D, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_ADC}, 0x7D, $self->{ADDR_ABSX}      , 3, 4);
	set_op($self->{INS_ADC}, 0x79, $self->{ADDR_ABSY}      , 3, 4);
	set_op($self->{INS_ADC}, 0x61, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_ADC}, 0x71, $self->{ADDR_POSTIDXIND}, 2, 5);

	# AND
	set_op($self->{INS_AND}, 0x29, $self->{ADDR_IMM}       , 2, 2);
	set_op($self->{INS_AND}, 0x25, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_AND}, 0x35, $self->{ADDR_ZPX}       , 2, 4);
	set_op($self->{INS_AND}, 0x2D, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_AND}, 0x3D, $self->{ADDR_ABSX}      , 3, 4);
	set_op($self->{INS_AND}, 0x39, $self->{ADDR_ABSY}      , 3, 4);
	set_op($self->{INS_AND}, 0x21, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_AND}, 0x31, $self->{ADDR_POSTIDXIND}, 2, 5);

	# ASL
	set_op($self->{INS_ASL}, 0x0A, $self->{ADDR_ACC} , 1, 2);
	set_op($self->{INS_ASL}, 0x06, $self->{ADDR_ZP}  , 2, 5);
	set_op($self->{INS_ASL}, 0x16, $self->{ADDR_ZPX} , 2, 6);
	set_op($self->{INS_ASL}, 0x0E, $self->{ADDR_ABS} , 3, 6);
	set_op($self->{INS_ASL}, 0x1E, $self->{ADDR_ABSX}, 3, 7);
	
	# BCC
	set_op($self->{INS_BCC}, 0x90, $self->{ADDR_REL}, 2, 2);

	# BCS
	set_op($self->{INS_BCS}, 0xB0, $self->{ADDR_REL}, 2, 2);

	# BEQ
	set_op($self->{INS_BEQ}, 0xF0, $self->{ADDR_REL}, 2, 2);

	# BIT
	set_op($self->{INS_BIT}, 0x24, $self->{ADDR_ZP} , 2, 3);
	set_op($self->{INS_BIT}, 0x2C, $self->{ADDR_ABS}, 3, 4);

	# BMI
	set_op($self->{INS_BMI}, 0x30, $self->{ADDR_REL}, 2, 2);

	# BNE
	set_op($self->{INS_BNE}, 0xD0, $self->{ADDR_REL}, 2, 2);

	# BPL
	set_op($self->{INS_BPL}, 0x10, $self->{ADDR_REL}, 2, 2);

	# BRK
	set_op($self->{INS_BRK}, 0x00, $self->{ADDR_IMP}, 1, 7);

	# BVC
	set_op($self->{INS_BVC}, 0x50, $self->{ADDR_REL}, 2, 2);

	# BVS
	set_op($self->{INS_BVS}, 0x80, $self->{ADDR_REL}, 2, 2);

	# CLC
	set_op($self->{INS_CLC}, 0x18, $self->{ADDR_IMP}, 1, 2);

	# CLD
	set_op($self->{INS_CLD}, 0xD8, $self->{ADDR_IMP}, 1, 2);

	# CLI
	set_op($self->{INS_CLI}, 0x58, $self->{ADDR_IMP}, 1, 2);

	# CLV
	set_op($self->{INS_CLV}, 0xB8, $self->{ADDR_IMP}, 1, 2);

	# CMP
	set_op($self->{INS_CMP}, 0xC9, $self->{ADDR_IMM}       , 2, 2);
	set_op($self->{INS_CMP}, 0xC5, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_CMP}, 0xD5, $self->{ADDR_ZPX}       , 2, 4);
	set_op($self->{INS_CMP}, 0xCD, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_CMP}, 0xDD, $self->{ADDR_ABSX}      , 3, 4);
	set_op($self->{INS_CMP}, 0xD9, $self->{ADDR_ABSY}      , 3, 4);
	set_op($self->{INS_CMP}, 0xC1, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_CMP}, 0xD1, $self->{ADDR_POSTIDXIND}, 2, 5);

	# CPX
	set_op($self->{INS_CPX}, 0xE0, $self->{ADDR_IMM}, 2, 2);
	set_op($self->{INS_CPX}, 0xE4, $self->{ADDR_ZP} , 2, 3);
	set_op($self->{INS_CPX}, 0xEC, $self->{ADDR_ABS}, 3, 4);

	# CPY
	set_op($self->{INS_CPY}, 0xC0, $self->{ADDR_IMM}, 2, 2);
	set_op($self->{INS_CPY}, 0xC4, $self->{ADDR_ZP} , 2, 3);
	set_op($self->{INS_CPY}, 0xCC, $self->{ADDR_ABS}, 3, 4);

	# DEC
	set_op($self->{INS_DEC}, 0xC6, $self->{ADDR_ZP}  , 2, 5);
	set_op($self->{INS_DEC}, 0xD6, $self->{ADDR_ZPX} , 2, 6);
	set_op($self->{INS_DEC}, 0xCE, $self->{ADDR_ABS} , 3, 6);
	set_op($self->{INS_DEC}, 0xDE, $self->{ADDR_ABSX}, 3, 7);

	# DEX
	set_op($self->{INS_DEX}, 0xCA, $self->{ADDR_IMP}, 1, 2);

	# DEY
	set_op($self->{INS_DEY}, 0x88, $self->{ADDR_IMP}, 1, 2);

	# EOR
	set_op($self->{INS_EOR}, 0x49, $self->{ADDR_IMM}       , 2, 2);
	set_op($self->{INS_EOR}, 0x45, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_EOR}, 0x55, $self->{ADDR_ZPX}       , 2, 4);
	set_op($self->{INS_EOR}, 0x4D, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_EOR}, 0x5D, $self->{ADDR_ABSX}      , 3, 4);
	set_op($self->{INS_EOR}, 0x59, $self->{ADDR_ABSY}      , 3, 4);
	set_op($self->{INS_EOR}, 0x41, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_EOR}, 0x51, $self->{ADDR_POSTIDXIND}, 2, 5);

	# INC
	set_op($self->{INS_INC}, 0xE6, $self->{ADDR_ZP}  , 2, 5);
	set_op($self->{INS_INC}, 0xF6, $self->{ADDR_ZPX} , 2, 6);
	set_op($self->{INS_INC}, 0xEE, $self->{ADDR_ABS} , 3, 6);
	set_op($self->{INS_INC}, 0xFE, $self->{ADDR_ABSX}, 3, 7);

	# INX
	set_op($self->{INS_INX}, 0xE8, $self->{ADDR_IMP}, 1, 2);

	# INY
	set_op($self->{INS_INY}, 0xC8, $self->{ADDR_IMP}, 1, 2);

	# JMP
	set_op($self->{INS_JMP}, 0x4C, $self->{ADDR_ABS}   , 3, 3);
	set_op($self->{INS_JMP}, 0x6C, $self->{ADDR_INDABS}, 3, 5);

	# JSR
	set_op($self->{INS_JSR}, 0x20, $self->{ADDR_ABS}, 3, 3);

	# LDA
	set_op($self->{INS_LDA}, 0xA9, $self->{ADDR_IMM}       , 2, 2);
	set_op($self->{INS_LDA}, 0xA5, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_LDA}, 0xB5, $self->{ADDR_ZPX}       , 2, 4);
	set_op($self->{INS_LDA}, 0xAD, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_LDA}, 0xBD, $self->{ADDR_ABSX}      , 3, 4);
	set_op($self->{INS_LDA}, 0xB9, $self->{ADDR_ABSY}      , 3, 4);
	set_op($self->{INS_LDA}, 0xA1, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_LDA}, 0xB1, $self->{ADDR_POSTIDXIND}, 2, 5);

	# LDX
	set_op($self->{INS_LDX}, 0xA2, $self->{ADDR_IMM} , 2, 2);
	set_op($self->{INS_LDX}, 0xA4, $self->{ADDR_ZP}  , 2, 3);
	set_op($self->{INS_LDX}, 0xB4, $self->{ADDR_ZPX} , 2, 4);
	set_op($self->{INS_LDX}, 0xAC, $self->{ADDR_ABS} , 3, 4);
	set_op($self->{INS_LDX}, 0xBC, $self->{ADDR_ABSX}, 3, 4);

	# LDY
	set_op($self->{INS_LDY}, 0xA0, $self->{ADDR_IMM} , 2, 2);
	set_op($self->{INS_LDY}, 0xA4, $self->{ADDR_ZP}  , 2, 3);
	set_op($self->{INS_LDY}, 0xB4, $self->{ADDR_ZPX} , 2, 4);
	set_op($self->{INS_LDY}, 0xAC, $self->{ADDR_ABS} , 3, 4);
	set_op($self->{INS_LDY}, 0xBC, $self->{ADDR_ABSX}, 3, 4);

	# LSR
	set_op($self->{INS_LSR}, 0x4A, $self->{ADDR_ACC} , 1, 2);
	set_op($self->{INS_LSR}, 0x46, $self->{ADDR_ZP}  , 2, 5);
	set_op($self->{INS_LSR}, 0x56, $self->{ADDR_ZPX} , 2, 6);
	set_op($self->{INS_LSR}, 0x4E, $self->{ADDR_ABS} , 3, 6);
	set_op($self->{INS_LSR}, 0x5E, $self->{ADDR_ABSX}, 3, 7);

	# NOP
	set_op($self->{INS_NOP}, 0xEA, $self->{ADDR_IMP}, 1, 2);

	# ORA
	set_op($self->{INS_ORA}, 0x09, $self->{ADDR_IMM}       , 2, 2);
	set_op($self->{INS_ORA}, 0x05, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_ORA}, 0x15, $self->{ADDR_ZPX}       , 2, 4);
	set_op($self->{INS_ORA}, 0x0D, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_ORA}, 0x1D, $self->{ADDR_ABSX}      , 3, 4);
	set_op($self->{INS_ORA}, 0x19, $self->{ADDR_ABSY}      , 3, 4);
	set_op($self->{INS_ORA}, 0x01, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_ORA}, 0x11, $self->{ADDR_POSTIDXIND}, 2, 5);

	# PHA
	set_op($self->{INS_PHA}, 0x48, $self->{ADDR_IMP}, 1, 3);

	# PHP
	set_op($self->{INS_PHP}, 0x08, $self->{ADDR_IMP}, 1, 3);

	# PLP
	set_op($self->{INS_PLP}, 0x28, $self->{ADDR_IMP}, 1, 4);

	# ROL
	set_op($self->{INS_ROL}, 0x2A, $self->{ADDR_ACC} , 1, 2);
	set_op($self->{INS_ROL}, 0x26, $self->{ADDR_ZP}  , 2, 5);
	set_op($self->{INS_ROL}, 0x36, $self->{ADDR_ZPX} , 2, 6);
	set_op($self->{INS_ROL}, 0x2E, $self->{ADDR_ABS} , 3, 6);
	set_op($self->{INS_ROL}, 0x3E, $self->{ADDR_ABSX}, 3, 7);

	# ROR
	set_op($self->{INS_ROR}, 0x6A, $self->{ADDR_ACC} , 1, 2);
	set_op($self->{INS_ROR}, 0x66, $self->{ADDR_ZP}  , 2, 5);
	set_op($self->{INS_ROR}, 0x76, $self->{ADDR_ZPX} , 2, 6);
	set_op($self->{INS_ROR}, 0x6E, $self->{ADDR_ABS} , 3, 6);
	set_op($self->{INS_ROR}, 0x7E, $self->{ADDR_ABSX}, 3, 7);

	# RTI
	set_op($self->{INS_RTI}, 0x40, $self->{ADDR_IMP}, 1, 6);

	# RTS
	set_op($self->{INS_RTS}, 0x60, $self->{ADDR_IMP}, 1, 6);

	# SBC
	set_op($self->{INS_SBC}, 0xE9, $self->{ADDR_IMM}       , 2, 2);
	set_op($self->{INS_SBC}, 0xE5, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_SBC}, 0xF5, $self->{ADDR_ZPX}       , 3, 4);
	set_op($self->{INS_SBC}, 0xED, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_SBC}, 0xFD, $self->{ADDR_ABSX}      , 3, 4);
	set_op($self->{INS_SBC}, 0xF9, $self->{ADDR_ABSY}      , 3, 4);
	set_op($self->{INS_SBC}, 0xE1, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_SBC}, 0xF1, $self->{ADDR_POSTIDXIND}, 2, 5);

	# SEC
	set_op($self->{INS_SEC}, 0x38, $self->{ADDR_IMP}, 1, 2);

	# SED
	set_op($self->{INS_SED}, 0xF8, $self->{ADDR_IMP}, 1, 2);

	# SEI
	set_op($self->{INS_SET}, 0x78, $self->{ADDR_IMP}, 1, 2);

	# STA
	set_op($self->{INS_STA}, 0x85, $self->{ADDR_ZP}        , 2, 3);
	set_op($self->{INS_STA}, 0x95, $self->{ADDR_ZPX}       , 2, 4);
	set_op($self->{INS_STA}, 0x8D, $self->{ADDR_ABS}       , 3, 4);
	set_op($self->{INS_STA}, 0x9D, $self->{ADDR_ABSX}      , 3, 5);
	set_op($self->{INS_STA}, 0x99, $self->{ADDR_ABSY}      , 3, 5);
	set_op($self->{INS_STA}, 0x81, $self->{ADDR_PREIDXIND} , 2, 6);
	set_op($self->{INS_STA}, 0x91, $self->{ADDR_POSTIDXIND}, 2, 6);

	# STX
	set_op($self->{INS_STX}, 0x86, $self->{ADDR_ZP} , 2, 3);
	set_op($self->{INS_STX}, 0x96, $self->{ADDR_ZPX}, 2, 4);
	set_op($self->{INS_STX}, 0x8E, $self->{ADDR_ABS}, 3, 4);

	# STY
	set_op($self->{INS_STY}, 0x84, $self->{ADDR_ZP} , 2, 3);
	set_op($self->{INS_STY}, 0x94, $self->{ADDR_ZPX}, 2, 4);
	set_op($self->{INS_STY}, 0x8C, $self->{ADDR_ABS}, 3, 4);

	# TAX
	set_op($self->{INS_TAX}, 0xAA, $self->{ADDR_IMP}, 1, 2);

	# TAY
	set_op($self->{INS_TAY}, 0xA8, $self->{ADDR_IMP}, 1, 2);

	# TSX
	set_op($self->{INS_TSX}, 0xBA, $self->{ADDR_IMP}, 1, 2);

	# TXA
	set_op($self->{INS_TXA}, 0x8A, $self->{ADDR_IMP}, 1, 2);

	# TXS
	set_op($self->{INS_TXS}, 0x9A, $self->{ADDR_IMP}, 1, 2);

	# TYA
	set_op($self->{INS_TYA}, 0x98, $self->{ADDR_IMP}, 1, 2);
}

sub set_op {
	my ($self, $inst, $op, $addr, $size, $cycles) = @_;

	$self->{opdata}[$op] = (($inst & 0xFF)      ) |
			     (($addr & 0xFF) <<  8) |
			     (($size & 0xFF) << 16) |
			     (($cycles &0xFF)<< 24) ;
}

1;
