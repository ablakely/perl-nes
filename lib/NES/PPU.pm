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

	# Control Flags Register 1
	$self->{f_nmi_on_vblank}			= 0;	# NMI on VBlank. 0 = disable, 1 = enable
	$self->{f_sprite_size}				= 0;	# Sprite size. 0 = 8x8, 1 = 8x16
	$self->{f_bg_pattern_table}			= 0;	# Backgound Pattern Table address. 0 = 0x0000, 1 = 0x1000
	$self->{f_sp_pattern_table}			= 0;	# Sprite Pattern Table. 0 = 0x0000, 1 = 0x1000
	$self->{f_addr_inc}					= 0;	# PPU Address Increment. 0 = 1, 1 = 32
	$self->{f_ntbl_address}				= 0;	# Name Table Address. 0 = 0x2000, 1 = 0x2400, 2 = 0x2800, 3 = 0x2C00

	# Control Flags Register 2
	$self->{f_color}					= 0;	# Background color. 0 = black, 1 = blue, 2 = green, 4 = red
	$self->{f_sp_visibility}			= 0;	# Sprite visibility. 0 = not displayed, 1 = displayed
	$self->{f_bg_visibility}			= 0;	# Backgroung visibility. 0 = not displayed, 1 = displayed
	$self->{f_sp_clipping}				= 0;	# Sprite clipping. 0 = Sprites invisible in left 8-pixel column, 1 = no clipping
	$self->{f_bg_clipping}				= 0;	# Background clipping. 0 = BG invisible in left 8-pixel column, 1 = no clipping
	$self->{f_disp_type}				= 0;	# Display type. 0 = color, 1 = monochrome

	# Counters
	$self->{cntFV}						= 0;
	$self->{cntV}						= 0;
	$self->{cntH}						= 0;
	$self->{cntVT}						= 0;
	$self->{cntHT}						= 0;

	# Registers
	$self->{regFV}						= 0;
	$self->{regV}						= 0;
	$self->{regH}						= 0;
	$self->{regVT}						= 0;
	$self->{regHT}						= 0;
	$self->{regFH}						= 0;
	$self->{regS}						= 0;

	# These are temporary variables used in rendering and sound procedures.
	# Their states outside of those procedures can be ignored.
	# TODO: investigate the use of this.
	$self->{curNt}						= undef;

	# Variables used when rendering
	$self->{attrib}						= ();
	$self->{attrib}[32]					= undef;
	$self->{buffer}						= ();
	$self->{buffer}[256*240]			= undef;
	$self->{prev_buffer}				= ();
	$self->{prev_buffer}[256*240]		= undef;
	$self->{bg_buffer}					= ();
	$self->{bg_buffer}[256*240]			= undef;
	$self->{pix_rendered}				= ();
	$self->{pix_rendered}[256*240]		= undef;

	$self->{valid_tile_data}			= undef;
	$self->{scantile}					= ();
	$self->{scantile}[32]				= undef;

	# Initialize misc vars
	$self->{scanline}					= 0;
	$self->{last_rendered_scanline}		= -1;
	$self->{cur_x}						= 0;

	# Sprite Data
	$self->{spr_x}						= (); 		# X Coordinate
	$self->{spr_x}[64]					= undef;
	$self->{spr_y}						= ();		# Y Coordinate
	$self->{spr_x}[64]					= undef;
	$self->{spr_tile}					= ();		# Tile Index (into pattern table)
	$self->{spr_tile}[64]				= undef;
	$self->{spr_col}					= ();		# Upper 2 bits of color
	$self->{spr_col}[64]				= undef;
	$self->{vert_flip}					= ();		# Vertical Flip
	$self->{vert_flip}[64]				= undef;
	$self->{hori_flip}					= ();		# Horizontal Flip
	$self->{hori_flip}[64]				= undef;
	$self->{bg_priority}				= ();		# Background priority
	$self->{bg_priority}[64]			= undef;
	$self->{spr0_hit_x}					= ();		# Sprite 0 hit X coordinate
	$self->{spr0_hit_x}[64]				= undef;
	$self->{spr0_hit_y}					= ();		# Sprite 0 hit Y coordinate
	$self->{spr0_hit_y}[64]				= undef;
	$self->{hit_spr0}					= 0;

	# Palette data
	$self->{spr_palette}				= ();
	$self->{spr_palette}[16]			= undef;
	$self->{img_palette}				= ();
	$self->{img_palette}[16]			= undef;

	# Create pattern table tile buffers
	$self->{pt_tile}					= ();
	$self->{pt_tile}[512]				= undef;

	for ($i = 0; $i < 512; $i++) {
		$self->{pt_tile}[$i]			= NES::PPU::Tile->new();
	}

	# Create name table buffers
	# Name table data
	$self->{n_table1}					= ();
	$self->{n_table1}[4]				= undef;
	$self->{current_mirroring}			= -1;
	$self->{name_table}					= ();
	$self->{name_table}[4]				= undef;

	for ($i = 0; $i < 4; $i++) {
		$self->{name_table}[$i] = NES::PPU::NameTable->new(32, 32, "Nt".$i);
	}

	# Initialize mirroring lookup table
	$self->{vram_mirror_table}			= ();
	$self->{vram_mirror_table}[0x8000]	= undef;

	for ($i = 0; $i < 0x8000; $i++) {
		$self->{vram_mirror_table}[$i] = $i;
	}

	$self->{pal_table} = NES::PPU::PaletteTable()->new();
	$self->{pal_table}->load_NTSC_palette();

	update_control_reg1(0);
	update_control_reg2(0);
}

# Sets nametable mirroring
sub set_mirroring {
	my ($self, $mirroring) = @_;

	if ($mirroring == $self->{current_mirroring}) {
		return;
	}

	$self->{current_mirroring} = $mirroring;
	trigger_rendering();

	# Remove mirroring
	if ($self->{vram_mirror_table} == undef) {
		$self->{vram_mirror_table}				= ();
		$self->{vram_mirror_table}[0x8000]		= undef;
	}

	for ($i = 0; $i < 0x8000; $i++) {
		$self->{vram_mirror_table}[$i] = $i;
	}

	# Palette mirroring
	define_mirror_region(0x3f20, 0x3f00, 0x20);
	define_mirror_region(0x3f40, 0x3f00, 0x20);
	define_mirror_region(0x3f80, 0x3f00, 0x20);
	define_mirror_region(0x3fc0, 0x3f00, 0x20);

	# Additional mirroring
	define_mirror_region(0x3000, 0x2000, 0xf00);
	define_mirror_region(0x4000, 0x0000, 0x4000);

	my $ROM = NES::ROM->new();

	if ($mirroring == $ROM->{HORIZONTAL_MIRRORING}) {
		# Horizontal mirroring

		$self->{n_table1}[0]		= 0;
		$self->{n_table1}[1]		= 0;
		$self->{n_table1}[2]		= 1;
		$self->{n_table1}[3]		= 1;

		define_mirror_region(0x2400, 0x2000, 0x400);
		define_mirror_region(0x2c00, 0x2800, 0x400);
	}
	elsif ($mirroring == $ROM->{VERTICAL_MIRRORING}) {
		# Vertical mirroring

		$self->{n_table1}[0]		= 0;
		$self->{n_table1}[1]		= 1;
		$self->{n_table1}[2]		= 0;
		$self->{n_table1}[3]		= 1;

		define_mirror_region(0x2800, 0x2000, 0x400);
		define_mirror_region(0x2c00, 0x2400, 0x400);
	}
	elsif ($mirroring == $ROM->{SINGLESCREEN_MIRRORING}) {
		# Single Screen mirroring

		$self->{n_table1}[0]		= 0;
		$self->{n_table1}[1]		= 0;
		$self->{n_table1}[2]		= 0;
		$self->{n_table1}[3]		= 0;

		define_mirror_region(0x2400, 0x2000, 0x400);
		define_mirror_region(0x2800, 0x2000, 0x400);
		define_mirror_region(0x2c00, 0x2000, 0x400);
	}
	elsif ($mirroring == $ROM->{SINGLESCREEN_MIRRORING2}) {
		$self->{n_table1}[0]		= 1;
		$self->{n_table1}[1]		= 1;
		$self->{n_table1}[2]		= 1;
		$self->{n_table1}[3]		= 1;

		define_mirror_region(0x2400, 0x2400, 0x400);
		define_mirror_region(0x2800, 0x2400, 0x400);
		define_mirror_region(0x2c00, 0x2400, 0x400);
	} else {
		# Assume four-screen mirroring


		$self->{n_table1}[0]			= 0;
		$self->{n_table1}[1]			= 1;
		$self->{n_table1}[2]			= 2;
		$self->{n_table1}[3]			= 3;
	}
}

# Define a mirrored area in the address lookup table
# Assumes the regions don't overlap.
# The 'to' region is the region that is physically in memory.

sub define_mirror_region {
	my ($self, $from_start, $to_start, $size) = @_;

	for (my $i = 0; $i < $size; $i++) {
		$self->{vram_mirror_table}[$from_start+$i] = $to_start+$i;
	}
}

sub start_vblank {
	my ($self) = @_;

	# Do NMI
	$self->{nes}->{cpu}->request_irq($NES::CPU::IRQ_NMI);

	# Make sure everything is rendered
	if ($self->{last_rendered_scanline} < 239) {
		render_frame_partially($self->{last_rendered_scanline}+1, 240-$self->{last_rendered_scanline});
	}

	# End frame
	end_frame();

	# Reset scanline counter
	$self->{last_rendered_scanline} = -1;
}

sub end_scanline {
	my ($self) = @_;

	given ($self->{scanline}) {
		when (19) {
			# Dummy scanline -- May be variable length

			if ($self->{dummy_cycle_toggle}) {
				# Remove dead cycle at end of scanline, for next scanline
				$self->{cur_x} = 1;
				$self->{dummy_cycle_toggle} = !$self->{dummy_cycle_toggle};
			}
		}

		when (20) {
			# Clear VBlank flag
			set_status_flag($self->{STATUS_VBLANK}, 0);

			# Clear sprite 0 hit flag
			set_status_flag($self->{STATUS_SPRITE0HIT}, 0);
			$self->{hit_spr0}		= 0;
			$self->{spr0_hit_x}		= -1;
			$self->{spr0_hit_y}		= -1;

			if ($self->{f_bg_visibility} == 1 || $self->{f_sp_visibility} == 1) {
				# Update counters

				$self->{cntFV}		= $self->{regFV};
				$self->{cntV}		= $self->{regV};
				$self->{cntH}		= $self->{regH};
				$self->{cntVT}		= $self->{regVT};
				$self->{cntHT}		= $self->{regHT};

				if ($self->{f_bg_visibility} == 1) {
					# Render dummy scanline

					render_bg_scanline(0, 0);
				}
			}
		}

		if ($self->{f_bg_visibility} == 1 && $self->{f_sp_visibility} == 1) {
			# Check sprite 0 hit for first scanline
			check_sprite0(0);
		}

		if ($self->{f_bg_visibility} == 1 || $self->{f_sp_visibility} == 1) {
			# Clock mapper IRQ counter

			$self->{nes}->{mmap}->clock_irq_counter();
		}
	}

	when (261) {
		# Dead scanline, no rendering.
		# Set VINT

		set_status_flag($self->{STATUS_VBLANK}, 1);
		$self->{request_end_frame} = 1;
		$self->{nmi_counter}       = 9;

		# Wrap around
		$self->{scanline} = -1;  # Will be incremented to 0
	}
	
	default {
		if ($self->{scanline} >= 21 && $self->{scanline} <= 260) {
			# Render normally

			if ($self->{f_bg_visibility} == 1) {
				if (!$self->{scanline_already_rendered}) {
					# Update scroll

					$self->{cntHT}		= $self->{regHT};
					$self->{cntH}		= $self->{regH};
					render_bg_scanline(1, $self->{scanline}-20);
				}

				$self->{scanline_already_rendered} = 0;

				# Check for sprite 0 (next scanline)

				if (!$self->{hit_spr0} && $self->{f_sp_visibility} == 1) {
					if ($self->{spr_x}[0] >= -7 && $self->{spr_x}[0] < 256 && $self->{spr_y}[0] + 1 <= ($self->{scanline} - 20)
						&& ($self->{spr_y}[0] + 1 + ($self->{f_sprite_size} == 0 ? 8 : 16)) >= ($self->{scanline} - 20)) {

						if (check_sprite0($self->{scanline} - 20)) {
							$self->{hit_spr0} = 1;
						}
					}
				}
			}

			if ($self->{f_bg_visibility} == 1 || $self->{f_sp_visibility} == 1) {
				# Clock mapper IRQ Counter

				$self->{nes}->{mmap}->clock_irq_counter();
			}
		}
	}

	$self->{scanline}++;
	regs_to_address();
	cnts_to_address();
}

sub start_frame {
	my ($self) = @_;

	# Set background color
	my $bg_color = 0;

	if ($self->{f_disp_type} == 0) {
		# Color display
		# f_color determines color emphasis
		# Use first entry of image palette as BG color.
		$bg_color = $self->{img_palette}[0];
	} else {
		# Monochrome display.
		# f_color determines the bg color

		given ($self->{f_color}) {
			when (0) {
				# Black

				$bg_color = 0x00000;
			}

			when (1) {
				# Green

				$bg_color = 0x00FF00;
			}

			when (2) {
				# Blue

				$bg_color = 0xFF0000;
			}

			when (3) {
				# Invalid.  Use black.

				$bg_color = 0x000000;
			}

			when (4) {
				# Red

				$bg_color = 0x0000FF;
			}

			default {
				# Invalid.  Use black.

				$bg_color = 0x0;
			}
		}
	}
	my $i;

	for ($i = 0; i < 256*240; $i++) {
		$self->{buffer}[$i] = $bg_color;
	}

	for ($i = 0; $i < $#$self->{pix_rendered}; $i++) {
		$self->{pix_rendered}[$i] = 65;
	}
}

sub end_frame {
	my ($self) = @_;
	my ($i, $x, $y);

	if ($self->{show_spr0_hit}) {
		# Spr 0 position
		if ($self->{spr_x}[0] >= 0 && $self->{spr_x}[0] < 256 && $self->{spr_y}[0] >= 0 && $self->{spr_y}[0] < 240) {
			for ($i = 0; $i < 256; $i++) {
				$self->{buffer}[($self->{spr_y}[0] << 8)+$i] = 0xFF5555;
			}

			for ($i = 0; $i < 240; $i++) {
				$self->{buffer}[($i << 8)+$self->{spr_x}[0]] = 0xFF5555;
			}
		}

		# Hit position
		if ($self->{spr0_hit_x} >= 0 && $self->{spr0_hit_x} < 256 && $self->{spr0_hit_y} >= 0 && $self->{spr0_hit_y} < 240) {
			for ($i = 0; $i < 256; $i++) {
				$self->{buffer}[($self->{spr0_hit_y} << 8)+$i] = 0x55FF55;
			}

			for ($i = 0; $i < 240; $i++) {
				$self->{buffer}[($i << 8) + $self->{spr0_hit_x}] = 0x55FF55;
			}
		}
	}

	# This is a bit lazy...
	# if either the sprites or the background should be clipped, both are
	# clipped after rendering is finished.

	if ($self->{clip_to_tv_size} || $self->{f_bg_clipping} == 0 || $self->{f_sp_clipping} == 0) {
		# Clip left 8-pixels column

		for ($y = 0; $y = 240; $y++) {
			for ($x = 0; $x < 8; $x++) {
				$self->{buffer}[($y << 8)+$x] = 0;
			}
		}
	}

	if ($self->{clip_to_tv_size}) {
		# Clip right 8 pixels column too

		for ($y = 0; $y < 240; $y++) {
			for ($x = 0; $x < 8; $x++) {
				$self->{buffer}[($y << 8) + 255 - $x] = 0;
			}
		}
	}

	# Clip top and bottom 8 pixels
	if ($self->{clip_to_tv_size}) {
		for ($y = 0; $y < 8; $y++) {
			for ($x = 0; $x < 256; $x++) {
				$self->{buffer}[($y << 8) + $x]				= 0;
				$self->{buffer}[((239 - $y) << 8) + $x]		= 0;
			}
		}
	}

	if ($self->{nes}->{opts}->{show_display}) {
		$self->{nes}->{ui}->write_frame($self->{buffer}, $self->{prev_buffer});
	}
}

sub update_control_reg1 {
	my ($self, $value) = @_;

	trigger_rendering();

	$self->{f_nmi_on_vblank}		= ($value >> 7)&1;
	$self->{f_sprite_size}			= ($value >> 5)&1;
	$self->{f_bg_pattern_table}		= ($value >> 4)&1;
	$self->{f_sp_pattern_table}		= ($value >> 3)&1;
	$self->{f_addr_inc}				= ($value >> 2)&1;
	$self->{f_ntbl_address}			= $value&3;

	$self->{regV}					= ($value >> 1)&1;
	$self->{regH}					= $value&1;
	$self->{regS}					= ($value >> 4)&1;
}

sub update_control_reg2 {
	my ($self, $value) = @_;

	trigger_rendering();

	$self->{f_color}				= ($value >> 5)&7;
	$self->{f_sp_visibility}		= ($value >> 4)&1;
	$self->{f_bg_visibility}		= ($value >> 3)&1;
	$self->{f_sp_clipping}			= ($value >> 2)&1;
	$self->{f_bg_clipping}			= ($value >> 1)&1;
	$self->{f_disp_type}			= $value&1;

	if ($self->{f_disp_type} == 0) }
		$self->{pal_table}->set_emphasis($self->{f_color});
	}
	update_palettes();
}

sub set_status_flag {
	my ($self, $flag, $value) = @_;

	my $n = 1 << $flag;
	$self->{nes}->{cpu}->{mem}[0x2002] = (($self->{nes}->{cpu}->{mem}[0x2002] & (255-$n)) | ($value ? $n : 0));
}

# CPU Register $2002:
# Read the status Register

sub read_status_register {
	my ($self) = @_;

	my $tmp = $self->{nes}->{cpu}->{mem}[0x2002];

	# Reset scroll & VRAM address toggle
	$self->{first_write}	= 1;

	# Clear VBlank flag
	set_status_flag($self->{STATUS_VBLANK}, 0);

	# Fetch status data
	return $tmp;
}

# CPU Register $2003:
# Write the SPR-RAM address that is used for sram_write
# (Register 0x2004 in CPU memory mao)

sub write_sram_address {
	my ($self, $address) = @_;

	$self->{sram_address} = $address;
}

# CPU Register $2004 (R):
# Read from SPR-RAM (Sprite RAM).  The address should be set first.

sub sram_load {
	my ($self) = @_;
	return $self->{sprite_mem}[$self->{sram_address}];
}

# CPU Register $2004 (W):
# Write to SPR-RAM (Sprite RAM).  The address should be set first.

sub sram_write {
	my ($self, $value) = @_;

	$self->{sprite_mem}[$self->{sram_address}] = $value;
	sprite_ram_write_update($self->{sram_address}, $value);

	$self->{sram_address}++; # Increment address
	$self->{sram_address} %= 0x100;
}

# CPU Register $2005
# Write to scroll registers.  The first write is vertical offset.
# Second is horizontal offset.

sub scroll_write {
	my ($self, $value) = @_;

	trigger_rendering();

	if ($self->{first_write}) {
		# First write, horizontal scroll
		$self->{regHT}		= ($value >> 3)&31;
		$self->{regFH}		= $value&7;
	} else {
		# Second write, vertical scroll
		$self->{regFV}		= $value&7;
		$self->{regVT}		= ($value >> 3)&31;
	}

	$self->{first_write} = !$self->{first_write};
}

# CPU Register $2006
# Sets the adress used when reading/writing from/to VRAM.
# The first write sets the high byte, the second the low byte.

sub write_vram_address {
	my ($self, $address) = @_;

	if ($self->{first_write}) {
		$self->{regFV}		= ($address >> 4)&3;
		$self->{regV}		= ($address >> 3)&1;
		$self->{regH}		= ($address >> 2)&1;
		$self->{regVT}		= ($self->{regVT}&7) | (($adress&3) << 3);
	} else {
		trigger_rendering();

		$self->{regVT}		= ($self->{regVT}&24) | (($address >> 5)&7);
		$self->{regHT}		= $address&31;

		$self->{cntFV}		= $self->{regFV};
		$self->{cntV}		= $self->{regV};
		$self->{cntH}		= $self->{regH};
		$self->{cntVT}		= $self->{regVT};
		$self->{cntHT}		= $self->{regHT};

		check_sprite0($self->{scanline} - 20);
	}

	$self->{first_write} = !$self->{first_write};

	# Invoke mapper latch
	cnts_to_address();

	if ($self->{vram_address} < 0x2000) {
		$self->{nes}->{mmap}->latch_access($self->{vram_address});
	}
}

# CPU Register $2007 (R)
# Read from PPU memory.  The address should be set first.

sub vram_load {
	my ($self) = @_;
	my $tmp;

	cnts_to_address();
	regs_to_address();

	# If address is in range 0x0000 - 0x3EFF, return buffered values
	if ($self->{vram_address} <= 0x3EFF) {
		$tmp = $self->{vram_buffered_read_value};

		# Update buffered value
		if ($self->{vram_address} < 0x2000) {
			$self->{vram_buffered_read_value} = $self->{vram_mem}[$self->{vram_address}];
		} else {
			$self->{vram_buffered_read_value} = mirrored_load($self->{vram_address});
		}

		# Mapper latch access
		if ($self->{vram_address} < 0x2000) {
			$self->{nes}->{mmap}->latch_access($self->{vram_address});
		}

		# Increment by either 1 or 32, depending on d2 of Control Register 1
		$self->{vram_address} += ($self->{f_addr_inc} == 1 ? 32 : 1);

		cnts_from_address();
		regs_from_address();

		return $tmp; # Return the previous buffered value
	}

	# No buffering in this mem range.  Read normally.
	$tmp = mirrored_load($self->{vram_address});

	# Increment by either 1 or 32, depending on d2 of control register 1
	$self->{vram_address} += ($self->{f_addr_inc} == 1 ? 32 : 1);

	cnts_from_address();
	regs_from_address();

	return $tmp;
}

# CPU Register $2007 (W)
# Write to PPU memory.  The address should be set first.

sub vram_write {
	my ($self, $value) = @_;

	trigger_rendering();
	cnts_to_address();
	regs_to_address();

	if ($self->{vram_address} >= 0x2000) {
		# Mirroring is used.
		mirrored_write($self->{vram_address}, $value);
	} else {
		# Write normally.
		write_mem($self->{vram_address}, $value);

		# Invoke mapper latch
		$self->{nes}->{mmap}->latch_access($self->{vram_address});
	}

	# Increment by either 1 or 32, depending on d2 of control register 1
	$self->{vram_address} += ($self->{f_addr_inc} == 1 ? 32 : 1);
	regs_from_address();
	cnts_from_address();
}

# CPU Register $4014
# Write 256 bytes of main memory into Sprite RAM
sub sram_dma {
	my ($self, $value) = @_;

	my $base_address = $value * 0x100;
	my $data;

	for (my $i = $self->{sram_address}; $i < 256; $i++) {
		$data 						= $self->{nes}->{cpu}->{mem}[$base_address + $i];
		$self->{sprite_mem}[$i]		= $data;
		sprite_ram_write_update($i, $data);
	}

	$self->{nes}->{cpu}->halt_cycles(513);
}

# Updates the scroll registers from a new VRAM address.
sub regs_from_address {
	my ($self) = @_;

	my $address 			= ($self->{vram_tmp_address} >> 8)&0xFF;
	$self->{regFV}			= ($address >> 4)&7;
	$self->{regV}			= ($address >> 3)&1;
	$self->{regH}			= ($address >> 2)&1;
	$self->{regVT}			= ($self->{regVT}&7) | (($address >> 5)&7);

	$address 				= $self->{vram_tmp_address} & 0xFF;
	$self->{regVT}			= ($self->{regVT} & 24) | (($address >> 5)&7);
	$self->{regHT}			= $address&31;
}

# Updates the scroll registers from a new VRAM address.
sub cnts_from_address {
	my ($self) = @_;

	my $address 			= ($self->{vram_address} >> 8)&0xFF;
	$self->{cntFV}			= ($address >> 4)&3;
	$self->{cntV}			= ($address >> 3)&1;
	$self->{cntH}			= ($address >> 2)&1;
	$self->{cntVT}			= ($self->{cntVT}&7) | (($address&3) << 3);

	$address 				= $self->{vram_address}&0xFF;
	$self->{cntVT}			= ($self->{cntVT}&24) | (($address >> 5)&7);
	$self->{cntHT}			= $address&31;
}

sub regs_to_address {
	my ($self) = @_;

	my $b1		= ($self->{regFV}&7) << 4;
	$b1        |= ($self->{regV}&1)  << 3;
	$b1        |= ($self->{regH}&1)  << 2;
	$b1        |= ($self->{regVT} >> 3)&3;

	my $b2		= ($self->{regVT}&7) << 5;
	$b2        |= $self->{regHT}&31;

	$self->{vram_tmp_address} = (($b1 << 8) | $b2)&0x7FFF;
}

sub cnts_to_address {
	my ($self) = @_;

	my $b1		= ($self->{cntFV}&7) << 4;
	$b1        |= ($self->{cntV}&1)  << 3;
	$b1        |= ($self->{cntH}&1)  << 2;
	$b1        |= ($self->{cntVT} >> 3)&3;

	my $b2		= ($self->{cntVT}&7) << 5;
	$b2        |= $self->{cntHT}&31;

	$self->{vram_address} = (($b1 << 8) | $b2)&0x7FFF;
}

sub inc_tile_counter {
	my ($self, $count) = @_;

	for (my $i = $count; $i != 0; $i--) {
		$self->{cntHT}++;

		if ($self->{cntHT} == 32) {
			$self->{cntHT} = 0;
			$self->{cntVT}++;

			if ($self->{cntVT} >= 30) {
				$self->{cntH} = 0;
				$self->{cntV}++;

				if ($self->{cntV} == 2) {
					$self->{cntV} = 0;
					$self->{cntFV}++;
					$self->{cntFV} &= 0x7;
				}
			}
		}
	}
}

# Reads from memory, taking into account mirroring
# and mapping of address ranges
sub mirrored_load {
	my ($self, $address) = @_;

	return $self->{vram_mem}[$self->{vram_mirror_table}[$address]];
}

# Writes memory, taking into account mirroring and mapping
# of address ranges.
sub mirrored_write {
	my ($self, $address, $value) = @_;

	if ($address >= 0x3F00 && $address < 0x3F20) {
		if ($address == 0x3F00 || $address == 0x3F10) {
			write_mem(0x3F00, $value);
			write_mem(0x3F10, $value);
		}
		elsif ($address == 0x3F04 || $address == 0x3F14) {
			write_mem(0x3F04, $value);
			write_mem(0x3F14, $value);
		}
		elsif ($address == 0x3F08 || $address == 0x3F18) {
			write_mem(0x3F08, $value);
			write_mem(0x3F18, $value);
		}
		elsif ($address == 0x3F0C || $address == 0x3F1C) {
			write_mem(0x3F0C, $value);
			write_mem(0x3F1C, $value);
		}
		else {
		write_mem($address, $value);
	} 
	else {
		# Use lookup table for mirrored address
		if ($address < $#$self->{vram_mirror_table}) {
			write_mem($self->{vram_mirror_table}[$address], $value);
		} else {
			# FIXME
			croak "Invalid VRAM address: ".sprintf("%X", $address);
		}
	}
}

sub trigger_rendering {
	my ($self) = @_;

	if ($self->{scanline} >= 21 && $self->{scanline} <= 260) {
		# Render sprites, and combine
		render_frame_partially($self->{last_rendered_scanline}+1, $self->{scanline} - 21 - $self->{last_rendered_scanline});

		# Set last rendered scanline
		$self->{last_rendered_scanline} = $self->{scanline} - 21;
	}
}

sub render_frame_partially {
	my ($self, $start_scan, $scan_count) = @_;

	if ($self->{f_sp_visibility} == 1) {
		render_sprites_partially($start_scan, $scan_count, 1);
	}

	if ($self->{f_bg_visibility} == 1) {
		my $si 			= $start_scan << 8;
		my $ei 			= ($start_scan + $scan_count) << 8;

		if ($ei > 0xF000) {
			$ei 		= 0xF000;
		}

		my $buffer 			= $self->{buffer};
		my $bg_buffer		= $self->{bg_buffer};
		my $pix_rendered	= $self->{pix_rendered};

		for (my $dest_index = $si; $dest_index < $ei; $dest_index++) {
			if ($pix_rendered[$dest_index] > 0xFF) {
				$buffer[$dest_index] = $bg_buffer[$dest_index];
			}
		}
	}

	if ($self->{f_sp_visibility} == 1) {
		render_sprites_partially($start_scan, $scan_count, 0);
	}

	$self->{valid_tile_data} = 0;
}

sub render_bg_scanline {
	my ($self, $bg_buffer, $scan) = @_;

	my $base_tile			= ($self->{regS} == 0 ? 0 : 256);
	my $dest_index			= ($scan << 8) - $self->{regFH};

	$self->{curNt}			= $self->{n_table1}[$self->{cntV} + $self->{cntV} + $self->{cntH}];

	$self->{cntHT}			= $self->{regHT};
	$self->{cntH}			= $self->{regH};
	$self->{curNt}			= $self->{n_table1}[$self->{cntV} + $self->{cntV} + $self->{cntH}];

	if ($scan < 240 && ($scan - $self->{cntFV}) >= 0) {
		my $tscanoffset 	= $self->{cntFV} << 3;
		my $scantile 		= $self->{scantile};
		my $attrib			= $self->{attrib};
		my $pt_tile			= $self->{pt_tile};
		my $name_table 		= $self->{name_table};
		my $img_palette		= $self->{img_palette};
		my $pix_rendered	= $self->{pix_rendered};
		my $target_buffer	= $bg_buffer ? $self->{bg_buffer} : $self->{buffer};

		my ($t, $tpix, $att, $col);

		for (my $tile = 0; $tile < 32; $tile++) {
			if ($scan >= 0) {
				# Fetch tile & attrib data

				if ($self->{valid_tile_data}) {
					# Get data from array

					$t 			= $scantile[$tile];
					$tpix 		= $t->{pix};
					$att 		= $attrib[$tile];
				} else {
					# Fetch data

					$t 					= $pt_tile[$base_tile + $name_table[$self->{curNt}]->get_tile_index($self->{cntHT}, $self->{cntVT})];
					$tpix 				= $t->{pix};
					$att 				= $name_table[$self->curNt]->get_attrib($self->{cntHT}, $self->{cntVT});
					$scantile[$tile]	= $t;
					$attrib[$tile]		= $att;
				}

				# Render tile scanline
				my $sx 		= 0;
				my $x 		= ($tile << 3) - $self->{regFH};

				if ($x > -8) {
					if ($x < 0) {
						$dest_index -= $x;
						$sx 		-= $x;
					}

					if ($t->{opaque}[$self->{cntFV}]) {
						for (;$sx < 8; $sx++) {
							$target_buffer[$dest_index] = $img_palette[$tpix[$tscanoffset+$sx]+$att];
							$pix_rendered[$dest_index] |= 256;
							$dest_index++;
						}
					} else {
						for (;$sx < 8; $sx++) {
							$col = $tpix[$tscanoffset+$sx];
							if ($col != 0) {
								$target_buffer[$dest_index] = $img_palette[$col+$att];
								$pix_rendered[$dest_index] |= 256;
							}
							$dest_index++;
						}
					}
				}
			}

			# Increase Horizontal Tile Counter
			if (++$self->{cntHT} == 32) {
				$self->{cntHT}			= 0;
				$self->{cntH}++;
				$self->{cntH}		   %= 2;
				$self->{curNt}			= $self->{n_table1}[($self->{cntV} << 1) + $cntH];
			}
		}

		# Tile data for one row should now have been fetched,
		# so the data in the array is valid.
		$self->{valid_tile_data} = 1;
	}

	# Update vertical scroll
	$self->{cntFV}++;
	if ($self->{cntFV} == 8) {

		$self->{cntFV} = 0;
		$self->{cntVT}++;

		if ($self->{cntVT} == 30) {
			$self->{cntVT} = 0;
			$self->{cntV}++;
			$self->{cntV} %= 2;
			$self->{curNt} = $self->{n_table1}[($self->{cntV} << 1) + $self->{cntH}];
		}
		elsif ($self->{cntVT} == 32) {
			$self->{cntVT} = 0;
		}

		# Invalidate fetched data
		$self->{valid_tile_data} = 0;
	}
}

sub render_sprites_partially {
	my ($self, $start_scan, $scan_count, $bg_pri) = @_;

	if ($self->{f_sp_visibility} == 1) {
		for (my $i = 0; $i < 64; $i++) {
			if ($self->{bg_priority}[$i] == $bg_pri && $self->{spr_x}[$i] >= 0 && $self->{spr_x}[$i] < 256
				&& $self->{spr_y}[$i]+8 >= $start_scan && $self->{spr_y}[$i] < $start_scan + $scan_count) {

				# Show sprite
				if ($self->{f_sprite_size} == 0) {
					# 8x8 sprites

					$self->{srcy1}		= 0;
					$self->{srcy2}		= 0;

					if ($self->{spr_y}[$i] < $start_scan) {
						$self->{srcy1} = $start_scan - $self->{spr_y}[$i] - 1;
					}

					if ($self->{spr_y}[$i] + 8 > $start_scan + $scan_count) {
						$self->{srcy2} = $start_scan + $scan_count - $self->{spr_y}[$i] + 1;
					}

					if ($self->{f_sp_pattern_table} == 0) {
						$self->{pt_tile}[$self->{spr_tile}[$i]]->render($self->{buffer}, 0, $self->{srcy1}, 8, $self->{srcy2},
																		$self->{spr_x}[$i], $self->{spr_y}[$i]+1, $self->{spr_col}[$i],
																		$self->{spr_palette}, $self->{hori_flip}[$i], $self->{vert_flip}[$i],
																		$i, $self->{pix_rendered});
					} else {
						$self->{pt_tile}[$self->{spr_tile}[$i]+256]->render($self->{buffer}, 0, $self->{srcy1}, 8, $self->{srcy2},
																			$self->{spr_x}[$i], $self->{spr_y}[$i]+1, $self->{spr_col}[$i],
																			$self->{spr_palette}, $self->{hori_flip}[$i], $self->{vert_flip}[$i],
																			$i, $self->{pix_rendered});
					}
				} else {
					# 8x16 sprites
					my $top 		= $self->{spr_tile}[$i];

					if (($top&1) == 0) {
						$top = $self->{spr_tile}[$i] - 1 + 256;
					}

					my $srcy1	= 0;
					my $srcy2 	= 8;

					if ($self->{spr_y}[$i] < $start_scan) {
						$srcy1 = $start_scan - $self->{spr_y}[$i] - 1;
					}

					if ($self->{spr_y}[$i] + 8 > $start_scan + $scan_count) {
						$srcy2 = $start_scan + $scan_count - $self->{spr_y}[$i];
					}

					$self->{pt_tile}[$top + ($self->{vert_flip}[$i] ? 1: 0)]->render(
						$self->buffer,
						0,
						$srcy1,
						8,
						$srcy2,
						$self->{spr_x}[$i],
						$self->{spr_y}[$i]+1,
						$self->{spr_col}[$i],
						$self->{spr_palette},
						$self->{hori_flip}[$i],
						$self->{vert_flip}[$i],
						$i,
						$self->{pix_rendered});

					$srcy1 		= 0;
					$srcy2 		= 8;

					if ($self->{spr_y}[$i] + 8 < $start_scan) {
						$srcy1 = $start_scan - ($self->{spr_y}[$i]+9);
					}

					if ($self->{spr_y}[$i] + 16 > $start_scan + $scan_count) {
						$srcy2 = $start_scan + $scan_count - ($self->{spr_y}[$i] + 8);
					}

					$self->{pt_tile}[$top + ($self->{vert_flip}[$i] ? 0 : 1)]->render(
						$self->{buffer},
						0,
						$srcy1,
						8,
						$srcy2,
						$self->{spr_x}[$i],
						$self->{spr_y}[$i]+9,
						$self->{spr_col}[$i],
						$self->{spr_palette},
						$self->{hori_flip}[$i],
						$self->{vert_flip}[$i],
						$i,
						$self->{pix_rendered});
				}
			}
		}
	}
}

sub check_sprite0 {
	my ($self, $scan) = @_;

	$self->{spr0_hit_x} = -1;
	$self->{spr0_hit_y} = -1;

	my $toffset;
	my $t_index_add = ($self->{f_sp_pattern_table} == 0 ? 0 : 256);
	my ($x, $y, $t, $i);
	my $buffer_index;
	my $col;
	my $bg_pri;

	$x = $self->{spr_x}[0];
	$y = $self->{spr_y}[0]+1;

	if ($self->{f_sprite_size} == 0) {
		# 8x8 sprites

		# Check range
		if ($y <= $scan && $y + 8 > $scan && $x >= -7 && $x < 256) {
			# Sprite is in range - draw scanline
			$t 			= $self->{pt_tile}[$self->{spr_tile}[0] + $t_index_add];
			$col 		= $self->{spr_col}[0];
			$bg_pri 	= $self->{bg_priority}[0];

			if ($self->{vert_flip}[0]) {
				$toffset = 7 - ($scan - $y);
			} else {
				$toffset = $scan - $y;
			}

			$toffset *= 8;

			$buffer_index = $scan * 256 + $x;
			if ($self->{hori_flip}[0]) {
				for ($i = 7; $i >= 0; $i--) {
					if ($x >= 0 && $x < 256) {
						if ($buffer_index >= 0 && $buffer_index < 61440 && $self->{pix_rendered}[$buffer_index] != 0) {
							if ($t->{pix}[$toffset+$i] != 0) {
								$self->{spr0_hit_x}		= $buffer_index % 256;
								$self->{spr0_hit_y}		= $scan;

								return 1;
							}
						}
					}
					$x++;
					$buffer_index++;
				}
			}
			else {
				for ($i = 0; $i < 8; $i++) {
					if ($x >= 0 && $x < 256) {
						if ($buffer_index >= 0 && $buffer_index < 61440 && $self->{pix_rendered}[$buffer_index] != 0) {
							if ($t->{pix}[$toffset+$i] != 0) {
								$self->{spr0_hit_x} 		= $buffer_index % 256;
								$self->{spr0_hit_y} 		= $scan;

								return 1;
							}
						}
					}
					$x++;
					$buffer_index++;
				}
			}
		}
	}
	else {
		# 8x16 sprite
		# Check range

		if ($y <= $scan && $y + 16 > $scan && $x >= -7 && $x < 256) {
			# Sprite is in range
			# Draw scanline

			if ($self->{vert_flip}[0]) {
				$toffset = 15 - ($scan - $y);
			} else {
				$toffset = $scan - $y;
			}

			if ($toffset < 8) {
				# First half of sprite

				$t 		= $self->{pt_tile}[$self->{spr_tile}[0]+($self->{vert_flip}[0]?1:0)+(($self->{spr_tile}[0]&1) != 0?255:0)];
			} else {
				# Second half of sprite
				$t 		= $self->{pt_tile}[$self->{spr_tile}[0]+($self->{vert_flip}[0]?0:1)+(($self->{spr_tile}[0]&1) != 0?255:0)];
				if ($self->{vert_flip}[0]) {
					$toffset = 15 - $offset;
				} else {
					$toffset -= 8;
				}
			}
			$toffset *= 8;
			$col 		= $self->{spr_col}[0];
			$bg_pri 	= $self->{bg_priority}[0];

			$buffer_index = $scan*256 + $x;
			if ($self->{hori_flip}[0]) {
				for ($i = 7; $i >= 0; $i--) {
					if ($x >= 0 && $x < 256) {
						if ($buffer_index >= 0 && $buffer_index < 61440 && $self->{pix_rendered}[$buffer_index] != 0) {
							if ($t->{pix}[$toffset+$i] != 0) {
								$self->{spr0_hit_x}		= $buffer_index % 256;
								$self->{spr0_hit_y} 	= $scan;

								return 1;
							}
						}
					}
					$x++;
					$buffer_index++;
				}
			} else {
				for ($i = 0; $i < 8; $i++) {
					if ($x >= 0 && $x < 256) {
						if ($buffer_index >= 0 && $buffer_index < 61440 && $self->{pix_rendered}[$buffer_index] != 0) {
							if ($t->{pix}[$toffset+$i] != 0) {
								$self->{spr0_hit_x} 	= $buffer_index % 256;
								$self->{spr0_hit_y}		= $scan;

								return 1;
							}
						}
					}
					$x++;
					$buffer_index++;
				}
			}
		}
	}
	return 0;
}

# This will write to PPU memory, and update internally buffered
# data appropriately.
sub write_mem {
	my ($self, $address, $value) = @_;

	$self->{vram_mem}[$address]		= $value;

	# Updates internally buffered data
	if ($address < 0x2000) {
		$self->{vram_mem}[$address] 	= $value;
		pattern_write($address, $value);
	}
	elsif ($address >= 0x2000 && $address < 0x23C0) {
		name_table_write($self->{n_table1}[0], $address - 0x2000, $value);
	}
	elsif ($address >= 0x23C0 && $address < 0x2400) {
		attrib_table_write($self->{n_table1}[0], $address - 0x23C0, $value);
	}
	elsif ($address >= 0x2400 && $address < 0x27C0) {
		name_table_write($self->{n_table1}[1], $address - 0x2400, $value);
	}
	elsif ($address >= 0x27C0 && $address < 0x2800) {
		attrib_table_write($self->{n_table1}[1], $address - 0x27C0, $value);
	}
	elsif ($address >= 0x2800 && $address < 0x2BC0) {
		name_table_write($self->{n_table1}[2], $address - 0x2800, $value);
	}
	elsif ($address >= 0x2BC0 && $address < 0x2C00) {
		attrib_table_write($self->{n_table1}[2], $address - 0x2BC0, $value);
	}
	elsif ($address >= 0x2C00 && $address < 0x2FC0) {
		name_table_write($self->{n_table1}[3], $address - 0x2C00, $value);
	}
	elsif ($address >= 0x2FC0 && $address < 0x3000) {
		attrib_table_write($self->{n_table1}[3], $address - 0x2FC0, $value);
	}
	elsif ($address >= 0x3F00 && $address < 0x3F20) {
		update_palettes();
	}
}

# Reads data from $3f00 to $f20 into the two buffered palettes.
sub update_palettes {
	my ($self) = @_;

	my $i;
	for ($i = 0; $i < 16; $i++) {
		if ($self->{f_disp_type} == 0) {
			$self->{img_palette}[$i] = $self->{pal_table}->get_entry($self->{vram_mem}[0x3F00 + $i] & 63);
		} else {
			$self->{img_palette}[$i] = $self->{pal_table}->get_entry($self->{vram_mem}[0x3F00 + $i] & 32);
		}
	}

	for ($i = 0; $i < 16; $i++) {
		if ($self->{f_disp_type} == 0) {
			$self->{spr_palette}[$i] = $self->{pal_table}->get_entry($self->{vram_mem}[0x3F10 + $i] & 63);
		} else {
			$self->{spr_palette}[$i] = $self->{pal_table}->get_entry($self->{vram_mem}[0x3F10 + $i] & 32);
		}
	}
}

# Updates the internal pattern table buffers
# with this new byte.  In the vNES, there is a version
# of this with 4 arguments which isn't used.
sub pattern_write {
	my ($self, $address, $value) = @_;

	my $tile_index 		= int($address / 16);
	my $left_over 		= $address % 16;

	if ($left_over < 8) {
		$self->{pt_tile}[$tile_index]->set_scanline($left_over, $value, $self->{vram_mem}[$address + 8]);
	} else {
		$self->{pt_tile}[$tile_index]->set_scanline($left_over-8, $self->{vram_mem}[$address - 8], $value);
	}
}

# Updates the internal name table buffers with this new byte.
sub name_table_write {
	my ($self, $index, $address, $value) = @_;

	# Update sprite 0 hit
	check_sprite0($self->{scanline}-20);
}

# Update the internal pattern table buffers
# with this new attribute table byte.
sub attrib_table_write {
	my ($self, $index, $address, $value) = @_;

	$self->{name_table}[$index]->write_attrib($address, $value);
}

# Updates the internally buffered sprite data
# with this new byte of info.
sub sprite_ram_write_update {
	my ($self, $address, $value) = @_;
	my $t_index = int($address / 4);

	if ($t_index == 0) {
		check_sprite0($self->{scanline} - 20);
	}

	if ($address % 4 == 0) {
		# Y coordinate
		$self->{spr_y}[$t_index] = $value;
	}
	elsif ($address % 4 == 1) {
		# Tile index
		$self->{spr_tile}[$t_index] = $value;
	}
	elsif ($address % 4 == 2) {
		# Attributes
		$self->{vert_flip}[$t_index] 		= (($value & 0x80) != 0);
		$self->{hori_flip}[$t_index] 		= (($value & 0x40) != 0);
		$self->{bg_priority}[$t_index] 		= (($value & 0x20) != 0);
		$self->{spr_col}[$t_index] 			= ($value & 3) << 2;
	}
	elsif ($address % 4 == 3) {
		# X coordinate
		$self->{spr_x}[$t_index] = $value;
	}
}

sub do_mni {
	my ($self) = @_;

	# Set VBlank flag
	set_status_flag($self->{STATUS_VBLANK}, 1);
	$self->{nes}->{cpu}->request_irq($self->{nes}->{cpu}->{IRQ_NMI});
}

1;