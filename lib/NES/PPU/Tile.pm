package NES::PPU::Tile;

use strict;
use warnings;
use Croak;

sub new {
	my ($class) = @_;
	my $self = {
		pix 			=> (),
		fb_index		=> undef,
		t_index 		=> undef,
		x 				=> undef,
		y 				=> undef,
		w 				=> undef,
		h 				=> undef,
		inc_x 			=> undef,
		inc_y 			=> undef,
		pal_index 		=> undef,
		tpri 			=> undef,
		c 				=> undef,
		initalized 		=> 0,
		opaque 			=> ()
	};

	return bless($self, $class);
}

sub set_buffer {
	my ($self, $scanline) = @_;

	for ($self->{y} = 0; $self->{y} < 8; $self->{y}++) {
		set_scanline($self->{y}, $scanline[$self->{y}], $scanline[$self->{y}+8]);
	}
}

sub set_scanline {
	my ($self, $sline, $b1, $b2) = @_;

	$self->{initalized} 		= 1;
	$self->{t_index} 			= $sline << 3;

	for ($self->{x} = 0; $self->{x} < 8; $self->{x}++) {
		$self->{pix}[$self->{t_index} + $self->{this_x}] = (($b1 >> (7 - $self->{x})) & 1) + ((($b2 >> (7 - $self->{x})) & 1) << 1);

		if ($self->{pix}[$self->{t_index} + $self->{x}] == 0) {
			$self->{opaque}[$sline] = 0;
		}
	}
}

sub render {
	my ($self, $buffer, $srcx1, $srcy1, $srcx2, $srcy2, $dx, $dy, $pal_add, $palette, $flip_horizontal, $flip_vertical, $pri, $pri_table) = @_;

	if ($dx < -7 || $dx >= 256 || $dy < -7 || $dy >= 240) {
		return;
	}

	$self->{w}		= $srcx2 - $srcx1;
	$self->{h}		= $srcy2 - $srcy1;

	if ($dx < 0) {
		$srcx1 -= $dx;
	}

	if ($dx + $srcx2 >= 256) {
		$srcx2 = 256 - $dx;
	}

	if ($dy < 0) {
		$srcy1 - $dy;
	}

	if ($dy + $srcy2 >= 240) {
		$srcy2 = 240 - $dy;
	}

	if (!$flip_horizontal && !$flip_vertical) {
		$self->{fb_index}		= ($dy << 8) + $dx;
		$self->{t_index}		= 0;

		for ($self->{y} = 0; $self->{y} < 8; $self->{y}++) {
			for ($self-{x} = 0; $self->{x} < 8; $self->{x}++) {
				if ($self->{x} >= $srcx1 && $self->{x} < $srcx2 && $self->{y} >= $src1 && $self->{y} < $srcy2) {
					$self->{pal_index} 		= $self->{pix}[$self->{t_index}];
					$self->{tpri}			= $pri_table[$self->{fb_index}];

					if ($self->{pal_index} != 0 && $pri <= ($self->{tpri}&0xFF)) {
						$buffer[$self->{fb_index}] 		= $palette[$self->{pal_index}+$pal_add];
						$self->{tpri} 			   		= ($self->{tpri}&0xF00) | $pri;
						$pri_table[$self->{fb_index}]	= $self->{tpri};
					}
				}
				$self->{fb_index}++;
				$self->{t_index}++;
			}
			$self->{fb_index}  -= 8;
			$self->{fb_index}  += 256;
		}
	} elsif ($flip_horizontal && !$flip_vertical) {
		$self->{fb_index} 		= ($dy << 8)+$dx;
		$self->{t_index} 		= 7;

		for ($self->{y} = 0; $self->{y} < 8; $self->{y}++) {
			for ($self->{x} = 0; $self->{x} < 8; $self->{x}++) {
				if ($self->{x} >= $srcx1 && $self->{x} < $srcx2 && $self->{y} >= $srcy1 && $self->{y} < $srcy2) {
					$self->{pal_index} 		= $self->{pix}[$self->{t_index}];
					$self->{tpri} 			= $pri_table[$self->{fb_index}];

					if ($self->{pal_index} != 0 && $pri <= ($self->{tpri}&0xFF)) {
						$buffer[$self->{fb_index}] 		= $palette[$self->{pal_index} + $pal_add];
						$self->{tpri} 					= ($self->{tpri} & 0xF00) | $pri;
						$pri_table[$self->{fb_index}] 	= $self->{tpri};
					}
				}
				$self->{fb_index}++;
				$self->{t_index}--;
			}
			$self->{fb_index} -= 8;
			$self->{fb_index} += 256;
			$self->{t_index}  += 16;
		}
	} elsif ($flip_vertical && !$flip_horizontal) {
		$self->{fb_index}		= ($dy << 8)+$dx;
		$self->{t_index} 		= 56;

		for ($self->{y} = 0; $self->{y} < 8; $self->{y}++) {
			for ($self->{x} = 0; $self->{x} < 8; $self->{x}++) {
				if ($self->{x} >= $srcx1 && $self->{x} < $srcx2 && $self->{y} >= $srcy1 && $self->{y} < $srcy2) {
					$self->{pal_index} 		= $self->{pix}[$self->{t_index}];
					$self->{tpri} 			= $pri_table[$self->{fb_index}];

					if ($self->{pal_index} != 0 && $pri <= ($self->{tpri}&0xFF)) {
						$buffer[$self->{fb_index}] 		= $palette[$self->{pal_index}+$pal_add];
						$self->{tpri}              		= ($self->{tpri} & 0xF00) | $pri;
						$pri_table{$self->{fb_index}}	= $self->{tpri};
					}
				}
				$self->{fb_index}++;
				$self->{t_index}++;
			}
			$self->{fb_index} -= 8;
			$self->{fb_index} += 256;
			$self->{t_index}  -= 16;
		}
	} else {
		$self->{fb_index} = ($dy << 8)+$dx;
		$self->{t_index}  = 63;

		for ($self->{y} = 0; $self->{y} < 8; $self->{y}++) {
			for ($self->{x} = 0; $self->{x} < 8; $self->{x}++) {
				if ($self->{x} >= $srcx1 && $self->{x} < $srcx2 && $self->{y} >= $srcy1 && $self->{y} < srcy2) {
					$self->{pal_index} 	= $self->{pix}[$self->{fb_index}];
					$self->{tpri} 		= $pri_table[$self->{fb_index}];

					if ($self->{pal_index} != 0 && $pri <= ($self->{tpri}&0xFF)) {
						$buffer[$self->{fb_index}] 		= $palette[$self->{pal_index}+$pal_add];
						$self->{tpri} 					= ($self->{tpri} & 0xFF) | $pri;
						$pri_table[$self->{fb_index}] 	= $self->{tpri};
					}
				}
				$self->{fb_index}++;
				$self->{t_index}--;
			}
			$self->{fb_index} -= 8;
			$self->{fb_index} += 256;
		}
	}
}

sub is_transparent {
	my ($self, $x, $y) = @_;

	return ($self->{pix}[($y << 3) + $x] == 0);
}

1;