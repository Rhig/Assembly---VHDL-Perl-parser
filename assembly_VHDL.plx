#!/usr/bin/perl
#parser.plx
use warnings;
use strict;
use POSIX ();
use Math::Round;
sub dec_to_hexa; sub modulus_fractions; sub dec_to_bit_arr; sub bits_to_hexa; sub hexa_to_bits; sub bits_to_dec; sub hexa_to_dec; sub setup; sub mode1n2_sub; sub mode1_sub; sub mode2_sub; sub mode3_sub; sub get_input; sub assembly_to_VHDL; sub parse_table; sub dec_to_10bit; sub dec_to_16bit; sub constant_assembly_to_VHDL; sub constant_VHDL_to_assembly; sub VHDL_to_assembly; sub record_registers; sub write_config;

#globals:
our %assembly;
our %VHDL;
our @header;
our @constants;
our @body;
our @footer;
our @registers;
our @old_file;
our %bits2hexa = ("0000" => '0', "0001" => '1', "0010" => '2', "0011" => '3',
		 "0100" => '4', "0101" => '5', "0110" => '6', "0111" => '7',
		 "1000" => '8', "1001" => '9', "1010" => 'a', "1011" => 'b',
		 "1100" => 'c', "1101" => 'd', "1110" => 'e', "1111" => 'f');
our %hexa2bits = reverse %bits2hexa;
our %addresses;

#############################################################
#
sub write_config {
	my $line;
	my $num_of_GRBs = 0;
	my $num_of_ARBs = 0;
	my $num_of_ACRBs = 0;
	my $reg;
	my $num_of_blocks = 0;
	my $num_of_warps = 0;
	my $num_of_cells=0;
	while ($line = shift @old_file) {
		if ($line !~ /^\s*--/ && $line !~ /\s*constant/) {
			record_registers(split(' ',$line));
		}
	}
	foreach $reg (@registers) {
		if ($reg =~ /ARB/) {
			$num_of_ARBs++;
		} elsif ($reg =~ /GRB/) {
			$num_of_GRBs++;
		} elsif ($reg =~ /ACRB/) {
			$num_of_ACRBs++;
		}
	}
	print "Starting configuration:\n";
	print "Please write the number of blocks in this program:\nconfig> ";
	while ($line = <>) {
		chomp($line);
		if ($line !~ /^\s*\d+\s*$/) {
			print "$line is not a positive integer! Please try again:\nconfig> ";
		} else {
			$num_of_blocks = $line;
			last;
		}
	}
	print "Please write the number of warps per block in this program:\nconfig> ";
	while ($line = <>) {
		chomp($line);
		if ($line !~ /^\s*\d+\s*$/) {
			print "$line is not a positive integer! Please try again:\nconfig> ";
		} else {
			$num_of_warps = $line;
			last;
		}
	}
	print "Please write the number of shared memory cells per block needed in this program:\nconfig> ";
	while ($line = <>) {
		chomp($line);
		if ($line !~ /^\s*\d+\s*$/) {
			print "$line is not a positive integer! Please try again:\nconfig> ";
		} else {
			$num_of_cells = $line;
			last;
		}
	}
	my $num_of_lines = POSIX::ceil($num_of_cells/8);
	my @config;
	my $len = 8 + $num_of_blocks + 4*$num_of_warps*$num_of_blocks;
	push @config, "\tconstant CONF_LEN	: integer := $len;\n";
	push @config, "\tconstant conf_arr	: conf_arr_type(0 to  CONF_LEN - 1) :=\n";
	push @config, "\t\t(core_conf_rst) & (core_conf_rst) & -- giving the CORE a bit of time to start\n";
	for (my $i=0; $i < $num_of_blocks ; $i++) {
		for (my $j = 0; $j < $num_of_warps ; $j++) {
			push @config, "\t\tconf_warp($j,$i,(others => '1')) &\n";
		}
		my $temp_warps = $num_of_warps - 1;
		push @config, "\t\t(conf_block($i,$i,$temp_warps)) &\n";
	}
	my $temp_ACRBs = POSIX::ceil($num_of_ACRBs/2);
	push @config, "\t\tconf_param($num_of_GRBs,$num_of_ARBs,$temp_ACRBs,$num_of_lines,$num_of_warps) &\n";
	push @config, "\t\t(core_conf_rst)\n\t\t;\n";
	unshift @constants, @config;
	print "Configuration finished!\n";
}

##############################################################
#Recieves any number of registers as input, stores them in the global "registers" array if they were not in the array before.
sub record_registers {
	my @new_regs=@_;
	my $new_reg;
	my $flag=0;
	my $reg;
	foreach $new_reg (@new_regs) {
		if ($new_reg !~ /(A|G|AC)RB\d/) {
			next;
		}
		$flag=0;
		foreach $reg (@registers) {
			if ($reg eq $new_reg) {
				$flag=1;
				last;
			}
		}
		if ($flag == 0) {
			push @registers, $new_reg;
		}
	}
	return;
}

##############################################################
#Convert a number to a hexadecimal string of equal value
#returns highest possible number if number is too high and lowest possible number if number is too low.
sub dec_to_hexa($$$) {
	my @bits = dec_to_bit_arr(@_);
	return bits_to_hexa(join("",@bits),$_[1]);
}

##############################################################
sub dec_to_bit_arr($$$) {
	my $num = $_[0];
	my $num_of_bits = $_[1];
	my $Q15 = $_[2];
	my @bits;
	my $i = 1;
	if ($Q15) {
		$num = round($num * 2**($num_of_bits-1));
	}
	if ($num < 0) {
		my $temp_num;
#		if ($Q15) {
#			$temp_num = -1*$num;
#		} else {
			$temp_num = 2**($num_of_bits-1) + $num;
			if ($temp_num < 0 ) {
				$temp_num = 0;
			}
#		}
		my @temp_bits = dec_to_bit_arr($temp_num,$num_of_bits,0);
		@bits = (1,@temp_bits[1..$num_of_bits-1]);
	} else {
		$bits[0] = 0;
		while ($i < $num_of_bits) {
			if ($num >= 2**($num_of_bits-$i-1)) {
				$bits[$i]=1;
				$num = $num - 2**($num_of_bits-$i-1);
			} else {
				$bits[$i] = 0;
			}
			$i++;
		}
	}
	return @bits;
}
##############################################################
sub bits_to_hexa($$) {
	my @bits = split("",$_[0]);
	my $num_of_bits = $_[1];
	my $i = $num_of_bits-1;
	my @hexa;
	while ($i > 2) {
		unshift @hexa, $bits2hexa{join("",@bits[($i-3)..$i])};
		$i = $i - 4;
	}
	if ($i < 0) {
		return join("",'x"',@hexa,'"');
	} else {
		return join("",('"',@bits[0..$i],'"&x"',@hexa,'"'));
	}
}
##############################################################
sub hexa_to_bits($) {
	my $input = $_[0];
	my @bits;
	my @hexa;
	my @out_bits;
	my $var;
	if ($input =~ /.(\d+).&x.((\d|\w)+)./) {
		@bits = split("",$1);
		@hexa = split("",$2);
		while (scalar(@hexa) != 0) {
			$var = pop(@hexa);
			unshift @out_bits, $hexa2bits{$var};
		}
		while (scalar(@bits) != 0) {
			$var = pop(@bits);
			unshift @out_bits, $var;
		}
		return join("",@out_bits);
	} elsif ($input =~ /x.((\d|\w)+)./) {
		@hexa = split("",$1);
		while (scalar(@hexa) != 0) {
			$var = pop(@hexa);
			unshift @out_bits, $hexa2bits{$var};
		}
		return join("",@out_bits);
	}
	return "";

}
##############################################################
sub bits_to_dec($$) {
	my @bits = split("",$_[0]);
	my $Q15 = $_[1];
	my $i = 0;
	my $num = 0;
	@bits = reverse @bits;
	while ($i < (scalar(@bits)-1)) {
		$num = $num + $bits[$i]*2**$i;
		$i++;
	}
	if ($Q15) {
		$num = $num/(2**$i);
	}
	if ($bits[$i]) {
		if ($Q15) {
			$num = -1*$num;
		} else {
			$num = -2**$i+$num;
		}
	} 
	return $num;
}
##############################################################
sub hexa_to_dec($$) {
	my $bits = hexa_to_bits($_[0]);
	return bits_to_dec($bits,$_[1]);
}

#####################################################
#User chooses mode
sub setup {
	my $line;
	print "Please choose the mode you want to work in:\n";
	print "1) Assembly-to-VHDL: Accepts input text file with assembly commands, writes VHDL file with the appropriate commands.\n";
	print "2) Interactive Assembly-to-VHDL: Accepts the assembly commands as user input, one at a time.\n";
	print "3) VHDL-to-Assembly: Accepts input VHDL file with machine commands, writes text file with the appropriate assembly commands.\n";
	print "\nPlease write the number of the mode you want to work with. Type 'quit' to abort: ";
	while ($line = <>) {
		chomp($line);
		if ($line eq 1) {
			print "Mode 1\n";
			return 1;
		} elsif ($line eq 2) {
			print "Mode 2\n";
			return 2;
		} elsif ($line eq 3) {
			print "Mode 3\n";
			return 3;
		} elsif ($line eq "quit") {
			return 0;
		} else {
			print "$line is not a legal mode value.\n";
		}
	}
}

###############################################################
#User gives input file
sub get_input {
	my $filename;
	my $fd;
	print "Please write down the input file path:\n";
	while ($filename = <>) {
		chomp($filename);
		if ($filename eq "abort") {
			exit(0);
		} elsif (-e $filename) {
			open($fd, $filename) or die $!;
			return ($fd, $filename);
		} else {
			print "$filename does not exist, please try again or write 'abort' to close the program\n";
		}
	}
}

##############################################################
#Read table and store data in global hashes
sub parse_table {
	my $table = "assembly_VHDL.csv";
	my $line;
	my $cmd;
	my $opcode;
	my $subopcode;
	my $r_D;
	my $r_A;
	my $r_B;
	if (-e $table) {
		open TABLE, $table or die $!;
		$line=<TABLE>;
		while ($line = <TABLE>) {
			chomp($line);
			($cmd, $opcode, $subopcode, $r_D, $r_A, $r_B) = split(',',$line);
			$assembly{"$cmd,$r_D,$r_A,$r_B"} = "$opcode,$subopcode";
			$VHDL{"$opcode,$subopcode"} = "$cmd,$r_D,$r_A,$r_B";
		}
	} else {
		print "ERROR! Can't find file $table in local directory!\n";
		exit(0);
	}
}

################################################################
#receive constant assembly declartion and insert VHDL constant declarations to the constants array
sub constant_assembly_to_VHDL {
	my $line = $_[0];
	my $name;
	my $value;
	my $xyz = 0;
	my $i = 0;
	if ($line =~ /\s*constant\s+(\w+)_ID_(X|Y|Z)_MASK\s+(\S+)/) {
		$xyz = $2;
		$name = "${1}_ID_${xyz}_MASK";
		$value = $3;
		if ($xyz eq "X") {
			$xyz = 1;
		} elsif ($xyz eq "Y") {
			$xyz = 2;
		} elsif ($xyz eq "Z") {
			$xyz = 3;
		} else {
			return;
		}
		$i = $xyz - 1;
		push @constants, "\tconstant $name\t\t\t\t: std_logic_vector(NATIVE_WORD_LEN - 1 downto 0) := zeros(NATIVE_WORD_LEN - $xyz*log2up($value)) & ones(log2up($value)) & zeros($i*log2up($value));\n";
	} elsif ($line =~ /\s*constant\s+(\S+)\s+(\S+)/) {
		$name = $1;
		$value = $2;
		push @constants, "\tconstant $name\t\t\t\t: integer := $value;\n";
		push @constants, "\tconstant ${name}_STD\t\t\t: std_logic_vector(NATIVE_WORD_LEN - 1 downto 0) := std_logic_vector(to_unsigned($name,NATIVE_WORD_LEN));\n";
		push @constants, "\tconstant ${name}_m1_STD\t\t\t: std_logic_vector(NATIVE_WORD_LEN - 1 downto 0) := std_logic_vector(to_unsigned($name - 1,NATIVE_WORD_LEN));\n";
		push @constants, "\tconstant LOG2UP_${name}_STD\t\t: std_logic_vector(NATIVE_WORD_LEN - 1 downto 0) := std_logic_vector(to_unsigned(log2up($name),NATIVE_WORD_LEN));\n";
		push @constants, "\tconstant LOG2UP_${name}_m1_STD\t\t: std_logic_vector(NATIVE_WORD_LEN - 1 downto 0) := std_logic_vector(to_unsigned(log2up($name) - 1,NATIVE_WORD_LEN));\n";
	} else {
		print "ERROR! the following constant-declartion line is not written according to the format 'constant <NAME> <INTEGER_VALUE>':\n$line\n";
	}
}

################################################################
#receive constant VHDL declartion and insert assembly constant declaration to the constants array
sub constant_VHDL_to_assembly {
	my $line = $_[0];
	my $name;
	my $value;
	if ($line =~ /\s*constant\s+(\S+)\s*:\s*integer\s*:=\s*(\S+)\s*;/) {
		$name = $1;
		$value = $2;
		if ($name ne "KERNEL_LEN") {
			push @constants, "constant $name $value\n";
		}
	} elsif ($line =~ /\s*constant\s+(\w+_ID_\w_MASK)\s*:\s*std_logic_vector\(NATIVE_WORD_LEN\s*-\s*1\s+downto\s+0\)\s*:=\s*zeros\(NATIVE_WORD_LEN\s*-\s*\d*\*?log2up\((\S+)\)\)\s*&\s*ones\(log2up\((\S+)\)\).*/) {
		if ($2 eq $3) {
			$name = $1;
			$value = $2;
			push @constants, "constant $name $value\n";
		}
	} elsif ($line =~ /\s*constant\s+(\S+)\s*:\s*std_logic_vector\(I_ADDR_LEN\s*-\s*1\s+downto\s+0\)\s+:=\s*std_logic_vector\(\s*to_unsigned\(\s*(\d+)\s*,\s*I_ADDR_LEN\s*\)\s*\)\s*;.*/) {
		$name = $1;
		$value = $2;
		$addresses{$name} = $value;
	}
}

################################################################
#Receive assembly command line as input and return VHDL command line as output
sub assembly_to_VHDL {
	my $line = $_[0];
	my $count = $_[1];
	my $opcode;
	my $subopcode;
	my $cmd;
	my $r_D;
	my $r_D_num;
	my $r_A;
	my $r_A_num;
	my $r_B;
	my $r_B_num;
	my $flag;
	#special case: modadr
	if ($line =~ /\s*modadr\s+(\S+)\s*/) {
		return "\t\tpack_i_modadr(\t(ARB_MODE_ADD_STEP, $1)),\n";
	}
	#special case: bkrep:
	if ($line =~ /bkrep\s+(\d+)\s+(\S+)\s*/) { 
		my $end_addr = $count + $1;
		my $reps = $2;
		if ($reps !~ /\S+_STD/) {
			$reps = "${reps}_STD";
		}
		push @constants, "\tconstant loop_end_addr_$end_addr\t: std_logic_vector(I_ADDR_LEN - 1 downto 0) := std_logic_vector(to_unsigned($end_addr,I_ADDR_LEN));\n";
		return "\t\tpack_i_bkrep((\"0\", loop_end_addr_$end_addr, $reps(log2up(MAX_NUM_OF_REP) - 1 downto 0))),\n";
	}
	#The order these conditions appear in is CRITICAL! Don't put a condition if it's shorter than the ones coming after it.
	#Case for 3 input registers
	if ($line =~ /\s*(\S+)\s+(GRB|ARB|ACRB)(\d+)\s+(GRB|ARB|ACRB)(\d+)\s+(GRB|ARB|ACRB)(\d+)(.*)/) {
		$cmd = $1;
		$r_D = $2;
		$r_D_num = $3;
		$r_A = $4;
		$r_A_num = $5;
		$r_B = $6;
		$r_B_num = $7;
		$flag = $8 if defined $8;
		if (defined $assembly{"$cmd,$r_D,$r_A,$r_B"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,$r_D,$r_A,$r_B"});
			$r_A_num = dec_to_hexa($r_A_num,10,0);
			$r_D_num = dec_to_hexa($r_D_num,10,0);
			$r_B_num = dec_to_hexa($r_B_num,16,0);
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
	#Case for 2 input registers and an immediate number
	} elsif ($line =~ /\s*(\S+)\s+(GRB|ARB|ACRB)(\d+)\s+(GRB|ARB|ACRB)(\d+)\s+(\S+)(.*)/) {
		$cmd = $1;
		$r_D = $2;
		$r_D_num = $3;
		$r_A = $4;
		$r_A_num = $5;
		$r_B_num = $6;
		$flag = $7 if defined $7;
		if (defined $assembly{"$cmd,$r_D,$r_A,IMM"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,$r_D,$r_A,IMM"});
			$r_A_num = dec_to_hexa($r_A_num,10,0);
			$r_D_num = dec_to_hexa($r_D_num,10,0);
			if ($r_B_num =~ /\b\d+\b/) {
				if ($r_B_num < 1 && $r_B_num >= -1) {
					$r_B_num = dec_to_hexa($r_B_num,16,1);
				} else {
					$r_B_num = dec_to_hexa($r_B_num,16,0);
				}
			}
		} elsif ($r_B_num eq "modify_addr") {
			$flag = $r_B_num;
			goto L1;
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
	#case for 2 input registers
	} elsif ($line =~ /\s*(\S+)\s+(GRB|ARB|ACRB)(\d+)\s+(GRB|ARB|ACRB)(\d+)(.*)/) {
		$cmd = $1;
		$r_D = $2;
		$r_D_num = $3;
		$r_A = $4;
		$r_A_num = $5;
		$flag = $6 if defined $6;
L1:		if (defined $assembly{"$cmd,$r_D,$r_A,"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,$r_D,$r_A,"});
			$r_A_num = dec_to_hexa($r_A_num,10,0);
			$r_D_num = dec_to_hexa($r_D_num,10,0);
			$r_B_num = dec_to_hexa(0,16,0);
		} elsif (defined $assembly{"$cmd,,$r_D,$r_A"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,,$r_D,$r_A"});
			$r_A_num = dec_to_hexa($r_D_num,10,0);
			$r_D_num = dec_to_hexa(0,10,0);
			$r_B_num = dec_to_hexa($r_A_num,16,0);
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
	#case for 1 input register and an immediate number
	} elsif ($line =~ /\s*(\S+)\s+(GRB|ARB|ACRB)(\d+)\s+(\S+)(.*)/) {
		$cmd = $1;
		$r_D = $2;
		$r_D_num = $3;
		$r_B_num = $4;
		$flag = $5 if defined $5;
		if (defined $assembly{"$cmd,$r_D,,IMM"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,$r_D,,IMM"});
			$r_A_num = dec_to_hexa(0,10,0);
			$r_D_num = dec_to_hexa($r_D_num,10,0);
			if ($r_B_num =~ /\b\d+\b/) {
				if ($r_B_num < 1 && $r_B_num >= -1) {
					$r_B_num = dec_to_hexa($r_B_num,16,1);
				} else {
					$r_B_num = dec_to_hexa($r_B_num,16,0);
				}
			}
		} elsif (defined $assembly{"$cmd,,$r_D,IMM"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,,$r_D,IMM"});
			$r_A_num = dec_to_hexa($r_D_num,10,0);
			$r_D_num = dec_to_hexa(0,10,0);
			if ($r_B_num =~ /\b\d+\b/) {
				if ($r_B_num < 1 && $r_B_num >= -1) {
					$r_B_num = dec_to_hexa($r_B_num,16,1);
				} else {
					$r_B_num = dec_to_hexa($r_B_num,16,0);
				}
			}
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
	#case for 1 input register
	} elsif ($line =~ /\s*(\S+)\s+(GRB|ARB|ACRB)(\d+)(.*)/) {
		$cmd = $1;
		$r_D = $2;
		$r_D_num = $3;
		$flag = $4 if defined $4;
		if (defined $assembly{"$cmd,$r_D,,"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,$r_D,,"});
			$r_A_num = dec_to_hexa(0,10,0);
			$r_D_num = dec_to_hexa($r_D_num,10,0);
			$r_B_num = dec_to_hexa(0,16,0);
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
	#case without input registers
	} elsif ($line =~ /\s*(\S+)\s*/) {
		$cmd = $1;
		if (defined $assembly{"$cmd,,,"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,,,"});
			$r_A_num = dec_to_hexa(0,10,0);
			$r_D_num = dec_to_hexa(0,10,0);
			$r_B_num = dec_to_hexa(0,16,0);
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
	} else {
		print "ERROR! Could not interpert the following line:\n$line\n";
		return "";
	}
	if (defined $flag && $flag =~ "modify_addr") {
		$flag = 1;
	} else {
		$flag = 0;
	}
	return "\t\tpack_i_general(\t('0',\t\t$opcode\t,\t'0',\t$r_D_num, $r_A_num, $r_B_num\t\t,  $subopcode , '$flag')),\n";
}

################################################################
#Receive VHDL command line as input and return assembly command line as output
sub VHDL_to_assembly {
	my $line = $_[0];
	my $count = $_[1];
	my $opcode;
	my $subopcode;
	my $cmd ="";
	my $r_D ="";
	my $r_D_num = "";
	my $r_A = "";
	my $r_A_num = "";
	my $r_B = "";
	my $r_B_num = "";
	my $mod_adr = "";
	my $flag = "";
	if ($line =~ /\s*pack_i_general\(\s*\(.\d.,\s*(\S+)\s*,\s*.\d.\s*,\s*("\d\d"&x"\S\S")\s*,\s*("\d\d"&x"\S\S")\s*,\s*(\S+|\(others => '0'\))\s*,\s*(\S+|\(others => '0'\))\s*,\s*.(\d).\s*\)\s*\)\s*.*/) {
		$opcode = $1;
		$r_D_num = hexa_to_dec($2,0);
		$r_A_num = hexa_to_dec($3,0);
		$r_B_num = $4;
		$r_B_num = 'x"0000"' if ($r_B_num eq "(others => '0')");
		$subopcode = $5;
		$mod_adr = $6;
		if (defined $VHDL{"$opcode,$subopcode"}) {
			($cmd, $r_D, $r_A, $r_B) = split(',', $VHDL{"$opcode,$subopcode"});
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
		$r_D_num = "" if ($r_D eq "");
		$r_A_num = "" if ($r_A eq "");
		if ($r_B_num =~ /(x"(\d|\w)(\d|\w)(\d|\w)(\d|\w)")/) {
			$r_B_num = hexa_to_dec($r_B_num,0);
		}
		$r_B_num = "" if ($r_B eq "");
		$r_B = "" if ($r_B eq "IMM");
		if ($mod_adr == 1) {
			$flag = " modify_addr";
		}
		return "$cmd $r_D$r_D_num $r_A$r_A_num $r_B$r_B_num$flag\n";
	} elsif ($line =~ /\s*pack_i_modadr\(\s*\(\s*ARB_MODE_ADD_STEP\s*,\s*(\S+)\s*\)\s*\)\s*,.*/) {
		return "modadr $1\n";
	} elsif ($line =~ /\s*pack_i_bkrep\(\s*\(\s*\S+\s*,\s*(\S+)\s*,\s*(\S+)\(log2up\(MAX_NUM_OF_REP\)\s*-\s*1\s+downto\s+0\s*\)\s*\)\s*\),/) {
		my $end_address = $1;
		my $reps = $2;
		my $num = 0;
		if (defined $addresses{$end_address}) {
			$end_address = $addresses{$end_address};
		}
		if ($end_address =~ /\d+/) {
			$num = $end_address - $count;
		}
		return "bkrep $num $reps\n";
	}
}

##########################################
#subroutine for mode 3
sub mode3_sub {
	my $fd;
	my $name;
	my $address = 0;
	($fd, $name) = get_input;
	my $line = <$fd>;
	push @old_file, $line;
	while ($line !~ /\s*package \S+ is\s*/) {
		$line = <$fd>;
		push @old_file, $line;
	}
	while ($line = <$fd>) {
		push @old_file, $line;
		chomp($line);
		if ($line =~ /\s*constant.*/) {
			constant_VHDL_to_assembly($line);
		} elsif ($line =~ /^\s*--.*/ && $line !~ /^\s*--\d+ : .*/) {
			push @body, "$line\n";
		} elsif ($line =~ /\s*pack_i_.*/) {
			$line = VHDL_to_assembly($line, $address);
			push @body, $line;
			$address++;
		}
	}
	return $name;
}

##########################################
#subroutine for mode 2
sub mode2_sub {
	my $name;
	my $line;
	my $const_flag = 0;
	my $address=0;
	my $cancel_flag = 1;
	print "Please write down the name of the program:\n";
	while ($name = <>) {
		chomp($name);
		if ($name eq "abort") {
			exit(0);
		} elsif ($name eq "") {
			print "An empty string is not a legal name. Please try again or write 'abort' to exit:\n";
		} else {
			last;
		}
	}
	push @header, "package $name is\n\n";
	push @footer, "\t);\n\n\n\nend $name;\n";
	print "Please write assembly commands. After each command, you will be presented with the VHDL translation, and it will be saved.\n";
	print "Write 'end' to finish writing the program. Write 'cancel' to cancel the latest line you've written.\n";
	while ($line = <>) {
		push @old_file, $line;
		chomp($line);
		if ($line =~ /\s*end\s*/) {
			unshift @constants, "\tconstant KERNEL_LEN\t\t: integer := $address;\n";
			return $name;
		} elsif ($line =~ /\s*cancel\s*/) {
			if ($cancel_flag == 1) {
				print "You can't use cancel twice in a row.\n";
			} elsif ($const_flag == 1) {
				for (my $i=0; $i < 5; $i++) {
					pop @constants;
				}
			} else {
				pop @body;
				pop @body;
				$address--;
				$cancel_flag = 1;
			}
		} elsif ($line =~ /^\s*--.*/ && $line !~ /^\s*--\d+ : .*/) {
			push @body, "$line\n";
		} elsif ($line =~ /\s*constant.*/) {
			constant_assembly_to_VHDL($line);
			$cancel_flag = 0;
			$const_flag = 1;
			print @constants;
		} else {
			push @body, "\t\t--$address : $line\n";
			$line = assembly_to_VHDL($line,$address);
			if ($line eq "") {
				pop @body;
			} else {
				push @body, $line;
				$address++;
			}
			print $line;
			$cancel_flag = 0;
			$const_flag = 0;
		}
	}
	return $name;
}

##########################################
#subroutine for mode 1
sub mode1_sub {
	my $fd;
	my $name;
	($fd, $name) = get_input;
	push @header, "package $name is\n\n";
	push @footer, "\t);\n\n\n\nend $name;\n";
	my $line;
	my $address=0;
	while ($line = <$fd>) {
		push @old_file, $line;
		chomp($line);
		if ($line =~ /\s*constant.*/) {
			constant_assembly_to_VHDL($line);
		} elsif ($line =~ /^\s*--.*/ && $line !~ /^\s*--\d+ : .*/) {
			push @body, "$line\n";
		} else {
			push @body, "\t\t--$address : $line\n";
			$line = assembly_to_VHDL($line,$address);
			if ($line eq "") {
				pop @body;
			} else {
				push @body, $line;
				$address++;
			}
		}
	}
	unshift @constants, "\tconstant KERNEL_LEN\t\t: integer := $address;\n";
	return $name;
}

##########################################
#subroutine for modes 1 & 2 (Assembly-to-VHDL)
sub mode1n2_sub {
	my $mode = $_[0];
	my $name;
	push @header, "library ieee;\n";
	push @header, "use ieee.std_logic_1164.all;\n";
	push @header, "use ieee.numeric_std.all;\n";
	push @header, "use std.textio.all;\n\n";
	push @header, "use work.general_pack.all;\n";
	push @header, "use work.core_pack.all;\n";
	push @header, "use work.opcode_pack.all;\n";
	push @header, "use work.CoreSim_pack.all;\n\n";
	push @body, "\tconstant i_arr : i_arr_type(0 to KERNEL_LEN -1) :=\n";
	push @body, "\t(-- \t\t\t\tmain_bit\tOpCode\t\t\t\t\tCondition\trD\t\t\trA\t\t\trB_IMM\t\t\t\t\t\tsubOpCode\t\t\t\t\tmodify_addr\t\n";
	if ($mode == 1) {
		$name = mode1_sub;
	} elsif ($mode == 2) {
		$name = mode2_sub;
	} else {
		print "ERROR! Illegal mode given to mode1n2_sub!\n";
	}
	write_config;
	return $name;
}

#############################################
#main
parse_table;
my $name;
my $mode = setup;
if ($mode == 1) {
	$name = mode1n2_sub(1);
	$name = "${name}.vhd";
} elsif ($mode == 2) {
	$name = mode1n2_sub(2);
	$name = "${name}.vhd";
} elsif ($mode == 3) {
	$name = mode3_sub;
	$name = "${name}.txt";
} elsif ($mode == 0) {
	exit(0);
}
open OUTPUT, "> $name" or die $!;
print OUTPUT @header;
print OUTPUT @constants;
print OUTPUT @body;
print OUTPUT @footer;
close OUTPUT;
print "The output file is named $name\n";
