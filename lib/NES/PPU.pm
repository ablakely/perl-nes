package NES::PPU;

use strict;
use warnings;

sub new {
	my ($class, $nes) = @_;

	my $self = {
		nes 						=> $nes,

		vram_mem					=> undef,
		sprite_mem					=> undef,
		vram_address				=> undef,
		vram_tmp_address			=> undef,
		vram_buffered_read_value	=> undef,
		first_write					=> undef,
		sram_address				=> undef,
		current_mirroring			=> undef,
		request_end_frame			=> undef,
		nmi_ok						=> undef,
		dummy_cycle_toggle			=> undef,
		valid_tile_data				=> undef,
		nmi_counter					=> undef,
		scanline_already_rendered	=> undef,
		f_nmi_on_vblank				=> undef,
		f_sprite_size				=> undef,
		f_bg_pattern_table			=> undef,
		f_sp_pattern_table			=> undef,
		f_addr_inc					=> undef,
		f_ntbl_address				=> undef,
		f_color						=> undef,
		f_sp_visibility				=> undef,
		f_bg_visibility				=> undef,
		f_sp_clipping				=> undef,
		f_bg_clipping				=> undef,
		f_disp_type					=> undef,
		cntFV						=> undef,
		cntV 						=> undef,
		cntH 						=> undef,
		cntVT 						=> undef,
		cntHT 						=> undef,
		regFV						=> undef,
		regV 						=> undef,
		regH 						=> undef,
		regVT 						=> undef,
		regFH 						=> undef,
		regS 						=> undef,
		curNt 						=> undef,
		attrib 						=> undef,
		buffer 						=> undef,
		prev_buffer 				=> undef,
		bg_buffer					=> undef,
		pix_rendered 				=> undef,

		valid_tile_data 			=> undef,
		scantile 					=> undef,
		scanline 					=> undef,
		last_rendered_scanline		=> undef,
		cur_x						=> undef,
		spr_x 						=> undef,
		spr_y 						=> undef,
		spr_tile 					=> undef,
		spr_col						=> undef,
		vert_flip					=> undef,
		hori_flip 					=> undef,
		bg_priority					=> undef,
		spr0_hit_x					=> undef,
		spr0_hit_y					=> undef,
		hit_spr0					=> undef,
		spr_palette					=> undef,
		img_palette					=> undef,
		pt_tile 					=> undef,
		n_table1 					=> undef,
		current_mirroring 			=> undef,
		name_table 					=> undef,
		vram_mirror_table			=> undef,
		pal_table 					=> undef,

		# Rendering Options
		show_spr0_hit				=> 0,
		clip_to_tv_size 			=> 1,

		# Status flags:
		STATUS_VRAMWRITE			=> 4,
		STATUS_SLSPRITECOUNT		=> 5,
		STATUS_SPRITE0HIT			=> 6,
		STATUS_VBLANK				=> 7
	};

	ppu_reset();

	return bless($self, $class);
}

sub ppu_reset {
	my ($self) = @_;
	my ($i);

	# Memory
	$self->{vram_mem}				= ();
	$self->{vram_mem}[0x8000]		= undef;

	$self->{sprite_mem}				= ();
	$self->{sprite_mem}[0x100]		= undef;

	for ($i = 0; $i < $#$self->{vram_mem}; $i++) {
		$self->{vram_mem}[$i] = 0;
	}

	for ($i = 0; $i < $#$self->{sprite_mem}; $i++) {
		$self->{sprite_mem}[$i] = 0;
	}

	# VRAM I/O
	$self->{vram_address}				= undef;
	$self->{vram_tmp_address}			= undef;
	$self->{vram_buffered_read_value}	= 0;
	$self->{first_write}				= 1; # VRAM/Scroll Hi/Lo latch

	# SPR-RAM I/O
	$self->{sram_address}				= 0; # 8-bit only

	$self->{current_mirroring}			= -1;
	$self->{request_end_frame}			= 0;
	$self->{nmi_ok}						= 0;
	$self->{dummy_cycle_toggle}			= 0;
	$self->{valid_tile_data}			= 0;
	$self->{nmi_counter}				= 0;
	$self->{scanline_already_rendered}	= undef;

	#
}