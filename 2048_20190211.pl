#! /us/bin/perl
# 2048.pl - 2048 Game (Perlバージョン)
# 実行例：perl .\2048.pl -auto_mode 3 -print_mode 1 -one_time 1
# 2019/01/26 PowerShell版(2019/01/23版)をPerlに移植開始
# 2019/02/11 オプション追加。移植完了

=begin comment
Game Over! (level=2 seed=10) 2019/02/11 19:45:30 #10 Ave.=47340.8 Max=179752(seed=7) Min=6228(seed=
getGap=60527635 calcGap=1175448108(10,0 55%,1 20000,1 10%,1 20000,1 1 calc_gap_mode=0
[10:3341] 54668 (0.00/2217.2 sec) 75000001.031605 2019/02/11 19:45:30 seed=10 2=74.95% Ave.=52807.6
 2048    64    16     4
 1024   256    64     2
  512   128    16     4
   32    16     8     2
Total time = 19036.082943(sec)
=end comment

=cut

use 5.010;
use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use Getopt::Long;

my $true = 1;
my $false = 0;
my $ticks_per_sec = 1000000;

my $auto_mode = 4; # >= 0 depth;
my $calc_gap_mode = 0; # gap計算モード(0:normal 1:端の方が小さければ+1 2:*2 3:+大きい方の値 4:+大きい方の値/10 5:+両方の値);
my $print_mode = 100;  #途中経過の表示間隔(0：表示しない);
my $print_mode_turbo = 1;
my $pause_mode = 0;
my $one_time = 1;
my $seed = 1;
my $turbo_minus_percent       = 55;
my $turbo_minus_percent_level = 1;
my $turbo_minus_score         = 20000;
my $turbo_minus_score_level   = 1;
my $turbo_plus_percent        = 10;
my $turbo_plus_percent_level  = 1;
my $turbo_plus_score          = 20000;
my $turbo_plus_score_level    = 1;

my $D_BONUS = 10;
my $D_BONUS_USE_MAX = $true; #10固定ではなく最大値とする;
my $D_GAP_EQUAL = 0;

my $D_INIT_2 = 1;
my $D_INIT_4 = 2;
my $D_RNDMAX = 4;
my $D_GAP_MAX = 100000000.0;
my $D_XMAX = 4;
my $D_YMAX = 4;
my $D_XMAX_1 = ($D_XMAX-1);
my $D_YMAX_1 = ($D_YMAX-1);

sub make_array {
    my ($x, $y, $v) = @_;
	my @ret;
	for (my $i = 0; $i < $x*$y; $i++) {
		$ret[$i] = $v;
	}
	return @ret;
}

my @board = make_array($D_XMAX, $D_YMAX, 0);
my $sp = 0;

my @pos_x;
my @pos_y;
my $score = 0;
my $gen = 0;
my $count_2 = 0;
my $count_4 = 0;
my $count_getGap = 0;
my $count_calcGap= 0;

my $start_time = &getTime;
my $last_time = &getTime;
my $total_start_time = 0;
my $total_last_time = 0;

my $count = 1;
my $sum_score = 0;
my $max_score = 0;
my $max_seed = 0;
my $min_score = $D_GAP_MAX;
my $min_seed = 0;

sub main {
	GetOptions(
		'auto_mode=i' => \$auto_mode,
		'calc_gap_mode=i' => \$calc_gap_mode,
		'print_mode=i' => \$print_mode,
		'print_mode_turbo=i' => \$print_mode_turbo,
		'pause_mode=i' => \$pause_mode,
		'seed=i' => \$seed,
		'one_time=i' => \$one_time,
		'turbo_minus_percent=i' => \$turbo_minus_percent,
		'turbo_minus_percent_level=i' => \$turbo_minus_percent_level,
		'turbo_minus_score=i' => \$turbo_minus_score,
		'turbo_minus_score_level=i' => \$turbo_minus_score_level,
		'turbo_plus_percent=i' => \$turbo_plus_percent,
		'turbo_plus_percent_level=i' => \$turbo_plus_percent_level,
		'turbo_plus_score=i' => \$turbo_plus_score,
		'turbo_plus_score_level=i' => \$turbo_plus_score_level
	);
	say "auto_mode=$auto_mode";
	say "calc_gap_mode=$calc_gap_mode";
	say "print_mode=$print_mode";
	say "print_mode_turbo=$print_mode_turbo";
	say "pause_mode=$pause_mode";
	say "seed=$seed";
	say "one_tim=$one_time";
	say "turbo_minus_percent=$turbo_minus_percent";
	say "turbo_minus_percent_level=$turbo_minus_percent_level";
	say "turbo_minus_score=$turbo_minus_score";
	say "turbo_minus_score_level=$turbo_minus_score_level";
	say "turbo_plus_percent=$turbo_plus_percent";
	say "turbo_plus_percent_level=$turbo_plus_percent_level";
	say "turbo_plus_score=$turbo_plus_score";
	say "turbo_plus_score_level=$turbo_plus_score_level";

	if ($seed > 0) {
		srand($seed);
	} else {
		srand(&getTime % 65535);
	}
	$total_start_time = &getTime;
	&init_game;
	while ($true) {
		my $gap = &moveAuto($auto_mode);
		$gen++;
		&appear;
		&disp($gap,($print_mode > 0 &&
			(($gen % $print_mode) == 0 ||
				($print_mode_turbo == 1 && $score > $turbo_minus_score) ||
				($print_mode_turbo == 2 && $score > $turbo_plus_score))));
		if (&isGameOver) {
			my $sc = &getScore;
			$sum_score += $sc;
			if ($sc > $max_score) {
				$max_score = $sc;
				$max_seed = $seed;
			}
			if ($sc < $min_score) {
				$min_score = $sc;
				$min_seed = $seed;
			}
			say "Game Over! (level=$auto_mode seed=$seed) ", &getTimeStr(&getTime), " #$count Ave.=", $sum_score/$count, " Max=$max_score(seed=$max_seed) Min=$min_score(seed=$min_seed)\ngetGap=$count_getGap calcGap=$count_calcGap($D_BONUS,$D_GAP_EQUAL $turbo_minus_percent%,$turbo_minus_percent_level $turbo_minus_score,$turbo_minus_score_level $turbo_plus_percent%,$turbo_plus_percent_level $turbo_plus_score,$turbo_plus_score_level $print_mode_turbo calc_gap_mode=$calc_gap_mode";
			&disp($gap, $true);
			if ($one_time > 0) {
				$one_time--;
				if ($one_time == 0) {
					last;
				}
			}
			if ($pause_mode > 0) {
				my $key;
				$key = <STDIN>;
				if ($key == "q" || $key == "Q") {
					last;
				}
			}
			$seed++;
			srand($seed);
			&init_game;
			$count++;
		}
	}
	$total_last_time = &getTime;
	say "Total time = ", ($total_last_time-$total_start_time)/$ticks_per_sec, "(sec)";
}

sub getCell {
    my ($x, $y) = @_;
	return $board[$x+$y*$D_XMAX];
}

sub setCell {
    my ($x, $y, $n) = @_;
	$board[$x+$y*$D_XMAX] = $n;
}

sub clearCell {
    my ($x, $y) = @_;
	&setCell($x, $y, 0);
}

sub copyCell {
    my ($x1, $y1, $x2, $y2) = @_;
	my $ret = &getCell($x1, $y1);
	&setCell($x2, $y2, $ret);
	return $ret;
}

sub moveCell {
    my ($x1, $y1, $x2, $y2) = @_;
	&copyCell($x1, $y1, $x2, $y2);
	&clearCell($x1, $y1);
}

sub addCell {
    my ($x1, $y1, $x2, $y2) = @_;
	$board[$x2+$y2*$D_XMAX]++;
	&clearCell($x1, $y1);
	if ($sp < 1) {
		my $val = &getCell($x2, $y2);
		my $tmp_score = 1 << $val;
		&addScore($tmp_score);
	}
}

sub isEmpty {
    my ($x, $y) = @_;
	my $ret = &getCell($x, $y);
	return $ret == 0;
}

sub isNotEmpty {
    my ($x, $y) = @_;
	return &getCell($x, $y) != 0;
}

sub isGameOver {
	my ($ret, undef, undef) = &isMovable;
	if ($ret) {
		return $false;
	} else {
		return $true;
	}
}

sub getScore {
	return $score;
}

sub setScore {
    my ($sc) = @_;
	$score = $sc;
	return &getScore;
}

sub addScore {
    my ($sc) = @_;
	$score += $sc;
	return &getScore;
}

sub clear_board {
	for (my $y = 0; $y < $D_YMAX; $y++) {
		for (my $x = 0; $x < $D_XMAX; $x++) {
			&clearCell($x, $y);
		}
	}
}

sub disp {
    my ($gap, $debug) = @_;
	my $s = "";
	my $now = &getTime;
	my $cur_time = ($now-$last_time)/$ticks_per_sec;
	my $all_time = ($now-$start_time)/$ticks_per_sec;
	my $cur_time_str = sprintf("%.2f", $cur_time);
	my $all_time_str = sprintf("%.1f", $all_time);
	my $gap_str = sprintf("%.6f", $gap);
	my $now_str = &getTimeStr($now);
	my $per_2 = sprintf("%.2f", $count_2 / ($count_2 + $count_4) * 100);
	my $getScore = &getScore;
	if ($count == 0) {
		print "[$count:$gen] $getScore ($cur_time_str/$all_time_str sec) $gap_str $now_str seed=$seed 2=$per_2%\r";
	} else {
		my $ave_str = "" . (($sum_score + $getScore)/$count);
		print "[$count:$gen] $getScore ($cur_time_str/$all_time_str sec) $gap_str $now_str seed=$seed 2=$per_2% Ave.=$ave_str\r";
	}
	$last_time = $now;
	if ($debug) {
		say "";
		for (my $y = 0; $y < $D_YMAX; $y++) {
			my $s = "";
			for (my $x = 0; $x < $D_XMAX; $x++) {
				my $v = &getCell($x, $y);
				if ($v > 0) {
					my $val = 1 << $v;
					$s .= sprintf("%5d", $val) . " ";
				} else {
					$s .= "    . ";
				}
			}
			say "$s";
		}
	}
}

sub dispBoard { # for debug ($b is reference of @board or @board_bak)
	my ($b) = @_;
	say "";
	for (my $y = 0; $y < $D_YMAX; $y++) {
		my $s = "";
		for (my $x = 0; $x < $D_XMAX; $x++) {
			my $v = $b->[$x+$y*$D_XMAX];
			if ($v > 0) {
				my $val = 1 << $v;
				$s .= sprintf("%5d", $val) . " ";
			} else {
				$s .= "    . ";
			}
		}
		say "$s";
	}
}

sub init_game {
	$gen = 1;
	&setScore(0);
	$start_time = &getTime;
	$last_time = $start_time;
	&clear_board;
	&appear;
	&appear;
	&disp(0.0, ($print_mode > 0));
}

sub getTime {
	my ($epocsec, $microsec) = gettimeofday;
	my ($sec,$min,$hour,$day,$month,$year) = localtime($epocsec);
	return $epocsec * $ticks_per_sec + $microsec;
}

sub getTimeArray {
	my ($time) = @_;
	my ($epocsec, $microsec) = $time/$ticks_per_sec;
	my ($sec,$min,$hour,$day,$month,$year) = localtime($epocsec);
	return ($sec,$min,$hour,$day,$month+1,$year+1900);
}

sub getTimeStr {
	my ($time) = @_;
	return sprintf("%4d/%02d/%02d %02d:%02d:%02d", (getTimeArray($time))[5,4,3,2,1,0]);
}

sub appear {
	my $n = 0;
	for (my $y = 0; $y < $D_YMAX; $y++) {
		for (my $x = 0; $x < $D_XMAX; $x++) {
			if (&isEmpty($x, $y)) {
				$pos_x[$n] = $x;
				$pos_y[$n] = $y;
				$n++;
			}
		}
	}
	if ($n > 0) {
		my $v;
		my $i = rand($count);
		my $val = rand(65535);
		if (($val % $D_RNDMAX) >= 1) {
			$v = $D_INIT_2;
			$count_2++;
		} else {
			$v = $D_INIT_4;
			$count_4++;
		}
		my $x = $pos_x[$i];
		my $y = $pos_y[$i];
		&setCell($x, $y, $v);
		return $true;
	}
	return $false;
}

sub countEmpty {
	my $ret = 0;
	for (my $y = 0; $y < $D_YMAX; $y++) {
		for (my $x = 0; $x < $D_XMAX; $x++) {
			my $isempty = &isEmpty($x, $y);
			if ($isempty) {
				$ret++;
			}
		}
	}
	return $ret;
}

sub move_up {
	my $move = 0;
	my $yLimit = 0;
	my $yNext = 0;
	for (my $x = 0; $x < $D_XMAX; $x++) {
		$yLimit = 0;
		for (my $y = 1; $y < $D_YMAX; $y++) {
			my $isnotempty = &isNotEmpty($x, $y);
			if ($isnotempty) {
				$yNext = $y - 1;
				while ($yNext >= $yLimit) {
					$isnotempty = &isNotEmpty($x, $yNext);
					if ($isnotempty) {
						last;
					}
					if ($yNext == 0) {
						last;
					}
					$yNext = $yNext - 1;
				}
				if ($yNext < $yLimit) {
					$yNext = $yLimit;
				}
				my $isempty = &isEmpty($x, $yNext);
				if ($isempty) {
					&moveCell($x, $y, $x, $yNext);
					$move++;
				} else {
					my $val1 = &getCell($x, $yNext);
					my $val2 = &getCell($x, $y);
					if ($val1 == $val2) {
						&addCell($x, $y, $x, $yNext);
						$move++;
						$yLimit = $yNext + 1;
					} else {
						my $yNext1 = $yNext+1;
						if ($yNext1 != $y) {
							&moveCell($x, $y, $x, $yNext1);
							$move++;
							$yLimit = $yNext1;
						}
					}
				}
			}
		}
	}
	return $move;
}

sub move_left {
	my $move = 0;
	my $xLimit = 0;
	my $xNext = 0;
	for (my $y = 0; $y < $D_YMAX; $y++) {
		$xLimit = 0;
		for (my $x = 1; $x < $D_XMAX; $x++) {
			my $isnotempty = &isNotEmpty($x, $y);
			if ($isnotempty) {
				$xNext = $x - 1;
				while ($xNext >= $xLimit) {
					my $isnotempty = &isNotEmpty($xNext, $y);
					if ($isnotempty) {
						last;
					}
					if ($xNext == 0) {
						last;
					}
					$xNext = $xNext - 1;
				}
				if ($xNext < $xLimit) {
					$xNext = $xLimit;
				}
				my $isempty = &isEmpty($xNext, $y);
				if ($isempty) {
					&moveCell($x, $y, $xNext, $y);
					$move++;
				} else {
					my $val1 = &getCell($xNext, $y);
					my $val2 = &getCell($x, $y);
					if ($val1 == $val2) {
						&addCell($x, $y, $xNext, $y);
						$move++;
						$xLimit = $xNext + 1;
					} else {
						my $xNext1 = $xNext + 1;
						if ($xNext1 != $x) {
							&moveCell($x, $y, $xNext1, $y);
							$move++;
							$xLimit = $xNext1;
						}
					}
				}
			}
		}
	}
	return $move;
}

sub move_down {
	my $move = 0;
	my $yLimit = 0;
	my $yNext = 0;
	for (my $x = 0; $x < $D_XMAX; $x++) {
		$yLimit = $D_YMAX - 1;
		for (my $y = $D_YMAX - 2; $y >= 0; $y--) {
			my $isnotempty = &isNotEmpty($x, $y);
			if ($isnotempty) {
				$yNext = $y + 1;
				while ($yNext <= $yLimit) {
					$isnotempty = &isNotEmpty($x, $yNext);
					if ($isnotempty) {
						last;
					}
					if ($yNext == $D_YMAX_1) {
						last;
					}
					$yNext = $yNext + 1;
				}
				if ($yNext > $yLimit) {
					$yNext = $yLimit;
				}
				my $isempty = &isEmpty($x, $yNext);
				if ($isempty) {
					&moveCell($x, $y, $x, $yNext);
					$move++;
				} else {
					my $val1 = &getCell($x, $yNext);
					my $val2 = &getCell($x, $y);
					if ($val1 == $val2) {
						&addCell($x, $y, $x, $yNext);
						$move++;
						$yLimit = $yNext - 1;
					} else {
						my $yNext1 = $yNext - 1;
						if ($yNext1 != $y) {
							&moveCell($x, $y, $x, $yNext1);
							$move++;
							$yLimit = $yNext1;
						}
					}
				}
			}
		}
	}
	return $move;
}

sub move_right {
	my $move = 0;
	my $xLimit = 0;
	my $xNext = 0;
	for (my $y = 0; $y < $D_YMAX; $y++) {
		$xLimit = $D_XMAX - 1;
		for (my $x = $D_XMAX - 2; $x >= 0; $x--) {
			my $isnotempty = &isNotEmpty($x, $y);
			if ($isnotempty) {
				$xNext = $x + 1;
				while ($xNext <= $xLimit) {
					$isnotempty = &isNotEmpty($xNext, $y);
					if ($isnotempty) {
						last;
					}
					if ($xNext == $D_XMAX_1) {
						last;
					}
					$xNext = $xNext + 1;
				}
				if ($xNext > $xLimit) {
					$xNext = $xLimit;
				}
				my $isempty = &isEmpty($xNext, $y);
				if ($isempty) {
					&moveCell($x, $y, $xNext, $y);
					$move++;
				} else {
					my $val1 = &getCell($xNext, $y);
					my $val2 = &getCell($x, $y);
					if ($val1 == $val2) {
						&addCell($x, $y, $xNext, $y);
						$move++;
						$xLimit = $xNext - 1;
					} else {
						my $xNext1 = $xNext - 1;
						if ($xNext1 != $x) {
							&moveCell($x, $y, $xNext1, $y);
							$move++;
							$xLimit = $xNext1;
						}
					}
				}
			}
		}
	}
	return $move;
}

sub moveAuto {
	my ($autoMode) = @_;
	my $empty = &countEmpty;
	my $sc = &getScore;
	if ($empty >= $D_XMAX*$D_YMAX*$turbo_minus_percent/100) {
		$autoMode -= $turbo_minus_percent_level;
	} elsif ($empty < $D_XMAX*$D_YMAX*$turbo_plus_percent/100) {
		$autoMode += $turbo_plus_percent_level;
	}
	if ($sc < $turbo_minus_score) {
		$autoMode -= $turbo_minus_score_level;
	} elsif ($sc >= $turbo_plus_score) {
		$autoMode += $turbo_plus_score_level;
	}
	my $ret = &moveBest($autoMode, $true);
	return $ret;
}

sub moveBest {
	my ($nAutoMode, $move) = @_;
	my $nGap = 0.0;
	my $nGapBest = $D_GAP_MAX;
	my $nDirBest = 0;
	my $nDir = 0;
	my @board_bak = &make_array($D_XMAX, $D_YMAX, 0);
	&copyBoard(\@board, \@board_bak);
	$sp++;
	$nGapBest = $D_GAP_MAX;
	my $val = &move_up;
	if ($val > 0) {
		$nDir = 1;
		$nGap = &getGap($nAutoMode, $nGapBest);
		if ($nGap < $nGapBest) {
			$nGapBest = $nGap;
			$nDirBest = 1;
		}
	}
	&copyBoard(\@board_bak, \@board);
	$val = &move_left;
	if ($val > 0) {
		$nDir = 2;
		$nGap = &getGap($nAutoMode, $nGapBest);
		if ($nGap < $nGapBest) {
			$nGapBest = $nGap;
			$nDirBest = 2;
		}
	}
	&copyBoard(\@board_bak, \@board);
	$val = &move_down;
	if ($val > 0) {
		$nDir = 3;
		$nGap = &getGap($nAutoMode, $nGapBest);
		if ($nGap < $nGapBest) {
			$nGapBest = $nGap;
			$nDirBest = 3;
		}
	}
	&copyBoard(\@board_bak, \@board);
	$val = &move_right;
	if ($val > 0) {
		$nDir = 4;
		$nGap = &getGap($nAutoMode, $nGapBest);
		if ($nGap < $nGapBest) {
			$nGapBest = $nGap;
			$nDirBest = 4;
		}
	}
	&copyBoard(\@board_bak, \@board);
	$sp--;
	if ($move) {
		if ($nDirBest == 0) {
			say "***** Give UP *****";
			$nDirBest = $nDir;
		}
		if ($nDirBest == 1) {
			&move_up;
		}
		elsif ($nDirBest == 2) {
			&move_left;
		}
		elsif ($nDirBest == 3) {
			&move_down;
		}
		elsif ($nDirBest == 4) {
			&move_right;
		}
	}
	return $nGapBest;
}

sub copyBoard {
	my ($a, $b) = @_;
	for (my $i = 0; $i < $D_XMAX*$D_YMAX; $i++) {
		$b->[$i] = $a->[$i];
	}
}

sub getGap {
	my ($nAutoMode, $nGapBest) = @_;
	$count_getGap++;
	my $ret = 0.0;
	my ($movable, $nEmpty, $nBonus) = &isMovable;
	if (! $movable) {
		$ret = $D_GAP_MAX;
	} elsif ($nAutoMode <= 1) {
		$ret = &getGap1($nGapBest, $nEmpty, $nBonus);
	} else {
		my $alpha = $nGapBest * $nEmpty; #累積がこれを超えれば、平均してもnGapBestを超えるので即枝刈りする
		for (my $x = 0; $x < $D_XMAX; $x++) {
			for (my $y = 0; $y < $D_YMAX; $y++) {
				if (&isEmpty($x, $y)) {
					my $nAutoMode1 = $nAutoMode-1;
					&setCell($x, $y, $D_INIT_2);
					my $best = &moveBest($nAutoMode1, $false);
					$ret += $best * ($D_RNDMAX - 1) / $D_RNDMAX;
					if ($ret >= $alpha) {
						return $D_GAP_MAX;
					}
					&setCell($x, $y, $D_INIT_4);
					$best = &moveBest($nAutoMode1, $false);
					$ret += $best / $D_RNDMAX;
					if ($ret >= $alpha) {
						return $D_GAP_MAX;
					}
					&clearCell($x, $y);
				}
			}
		}
		$ret /= $nEmpty;
	}
	return $ret;
}

sub getGap1 {
	my ($nGapBest, $nEmpty, $nBonus) = @_;
	my $ret = 0.0;
	my $ret_appear = 0.0;
	my $alpha = $nGapBest * $nBonus;
	my $edgea = $false;
	my $edgeb = $false;
	for (my $x = 0; $x < $D_XMAX; $x++) {
		for (my $y = 0; $y < $D_YMAX; $y++) {
			my $v = &getCell($x, $y);
			$edgea = ($x == 0 || $y == 0 || $x == $D_XMAX_1 || $y == $D_YMAX_1);
			if ($v > 0) {
				if ($x < $D_XMAX_1) {
					my $x1 = &getCell(($x+1), $y);
					$edgeb = ($y == 0) || ($x+1 == $D_XMAX_1 || $y == $D_YMAX_1);
					if ($x1 > 0) {
						$ret += &calcGap($v, $x1, $edgea, $edgeb);
					} else {
						my $calcGap = &calcGap($v, $D_INIT_2, $edgea, $edgeb);
						$ret_appear += $calcGap * ($D_RNDMAX - 1) / $D_RNDMAX;
						$calcGap = &calcGap($v, $D_INIT_4, $edgea, $edgeb);
						$ret_appear += $calcGap / $D_RNDMAX;
					}
				}
				if ($y < $D_YMAX_1) {
					my $y1 = &getCell($x, ($y+1));
					$edgeb = ($x == 0) || ($x == $D_XMAX_1 || $y+1 == $D_YMAX_1);
					if ($y1 > 0) {
						$ret += &calcGap($v, $y1, $edgea, $edgeb);
					} else {
						my $calcGap = &calcGap($v, $D_INIT_2, $edgea, $edgeb);
						$ret_appear += $calcGap * ($D_RNDMAX - 1) / $D_RNDMAX;
						$calcGap = &calcGap($v, $D_INIT_4, $edgea, $edgeb);
						$ret_appear += $calcGap / $D_RNDMAX;
					}
				}
			}
			else {
				if ($x < $D_XMAX_1) {
					my $x1 = &getCell(($x+1), $y);
					$edgeb = ($y == 0) || ($x+1 == $D_XMAX_1 || $y == $D_YMAX_1);
					if ($x1 > 0) {
						my $calcGap = &calcGap($D_INIT_2, $x1, $edgea, $edgeb);
						$ret_appear += $calcGap * ($D_RNDMAX - 1) / $D_RNDMAX;
						$calcGap = &calcGap($D_INIT_4, $x1, $edgea, $edgeb);
						$ret_appear += $calcGap / $D_RNDMAX;
					}
				}
				if ($y < $D_YMAX_1) {
					my $y1 = &getCell($x, ($y+1));
					$edgeb = ($x == 0) || ($x == $D_XMAX_1 || $y+1 == $D_YMAX_1);
					if ($y1 > 0) {
						my $calcGap = &calcGap($D_INIT_2, $y1, $edgea, $edgeb);
						$ret_appear += $calcGap * ($D_RNDMAX - 1) / $D_RNDMAX;
						$calcGap = &calcGap($D_INIT_4, $y1, $edgea, $edgeb);
						$ret_appear += $calcGap / $D_RNDMAX;
					}
				}
			}
			if (($ret + ($ret_appear/$nEmpty)) > $alpha) {
				return $D_GAP_MAX;
			}
		}
	}
	$ret += $ret_appear / $nEmpty;
	$ret /= $nBonus;
	return $ret;
}

sub calcGap {
	my ($a, $b, $edgea, $edgeb) = @_;
	$count_calcGap++;
	my $ret = 0;
	if ($a > $b) {
		$ret = $a - $b;
		if ($calc_gap_mode < 0 && ! $edgea && $edgeb) {
			if ($calc_gap_mode == 1) {
				$ret += 1;
			}
			elsif ($calc_gap_mode == 2) {
				$ret *= 2;
			}
			elsif ($calc_gap_mode == 3) {
				$ret += $a;
			}
			elsif ($calc_gap_mode == 4) {
				$ret += $a/10;
			}
			elsif ($calc_gap_mode == 5) {
				$ret += $a+$b;
			}
		}
	} elsif ($a < $b) {
		$ret = $b - $a;
		if ($calc_gap_mode > 0 && $edgea && ! $edgeb) {
			if ($calc_gap_mode == 1) {
				$ret += 1;
			}
			elsif ($calc_gap_mode == 2) {
				$ret *= 2;
			}
			elsif ($calc_gap_mode == 3) {
				$ret += $a;
			}
			elsif ($calc_gap_mode == 4) {
				$ret += $a/10;
			}
			elsif ($calc_gap_mode == 5) {
				$ret += $a+$b;
			}
		}
	} else {
		$ret = $D_GAP_EQUAL;
	}
	return $ret;
}

sub isMovable {
	my $ret = $false; #動けるか？
	my $nEmpty = 0; #空きの数
	my $nBonus = 1.0; #ボーナス（隅が最大値ならD_BONUS）
	my $max_x = 0;
	my $max_y = 0;
	my $max = 0;
	for (my $y = 0; $y < $D_YMAX; $y++) {
		for (my $x = 0; $x < $D_XMAX; $x++) {
			my $val = &getCell($x, $y);
			if ($val == 0) {
				$ret = $true;
				$nEmpty++;
			} else {
				if ($val > $max) {
					$max = $val;
					$max_x = $x;
					$max_y = $y;
				}
				if (! $ret) {
					if ($x < $D_XMAX_1) {
						my $x1 = &getCell(($x+1), $y);
						if ($val == $x1 || $x1 == 0) {
							$ret = $true;
						}
					}
					if ($y < $D_YMAX_1) {
						my $y1 = &getCell($x, ($y+1));
						if ($val == $y1 || $y1 == 0) {
							$ret = $true;
						}
					}
				}
			}
		}
	}
	if (($max_x == 0 || $max_x == $D_XMAX_1) &&
		($max_y == 0 || $max_y == $D_YMAX_1)) {
		if ($D_BONUS_USE_MAX) {
			$nBonus = $max;
		} else {
			$nBonus = $D_BONUS;
		}
	}
	return ($ret, $nEmpty, $nBonus);
}

&main;
