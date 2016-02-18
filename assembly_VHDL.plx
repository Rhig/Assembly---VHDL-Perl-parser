#!/usr/bin/perl
#assembly_VHDL.plx
use warnings;
use strict;
use integer; #important for integer division when converting decimal number to bit strings.
sub setup; sub mode1n2_sub; sub mode1_sub; sub mode2_sub; sub mode3_sub; sub get_input; sub assembly_to_VHDL; sub parse_table; sub dec_to_10bit; sub dec_to_16bit; sub constant_assembly_to_VHDL; sub constant_VHDL_to_assembly; sub VHDL_to_assembly; sub hexa_to_dec;

#globals:
our %assembly;
our %VHDL;
our @header;
our @constants;
our @body;
our @footer;
our %dec2hexa = (0 => '0', 1 => '1', 2 => '2', 3 => '3',
		 4 => '4', 5 => '5', 6 => '6', 7 => '7',
		 8 => '8', 9 => '9', 10 => 'a', 11 => 'b',
		 12 => 'c', 13 => 'd', 14 => 'e', 15 => 'f');
our %hexa2dec = reverse %dec2hexa;
our %addresses;

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

##############################################################
#Convert a number to a hexadecimal string of equal value
#returns 0x"ffff" if number is too high
sub dec_to_16bit($) {
	my $num = $_[0];
	my @hexa;
	my $i = 3;
	if ($num > 2**16-1) {
		return 'x"ffff"';
	}
	while ($i >= 0) {
		if ($num > 16**$i - 1) {
			$hexa[3-$i] = $dec2hexa{$num/(16**$i)};
			$num = $num % (16**$i);
		} else {
			$hexa[3-$i] = $dec2hexa{0};
		}
		$i = $i -1;
	}
	return "x\"$hexa[0]$hexa[1]$hexa[2]$hexa[3]\"";
}

##############################################################
#Convert a number to a hexadecimal string of equal value
#returns "11"&x"ff" if number is too high
sub dec_to_10bit($) {
	my $num = $_[0];
	my @hexa;
	my $i = 1;
	if ($num > 2**10-1) {
		return '"11"&x"ff"';
	}
	$hexa[0] = $dec2hexa{$num/(2**9)};
	$num = $num % (2**9);
	$hexa[1] = $dec2hexa{$num/(2**8)};
	$num = $num % (2**8);	
	while ($i >= 0) {
		if ($num > 16**$i - 1) {
			$hexa[3-$i] = $dec2hexa{$num/(16**$i)};
			$num = $num % (16**$i);
		} else {
			$hexa[3-$i] = $dec2hexa{0};
		}
		$i = $i -1;
	}
	return "\"$hexa[0]$hexa[1]\"&x\"$hexa[2]$hexa[3]\"";
}

##############################################################
#Convert a hexadecimal string to a number of equal value
sub hexa_to_dec($) {
	my $string = $_[0];
	my $num;
	if ($string =~ /.(\d)(\d).&x.(\d|\w)(\d|\w)./) {
		$num = $1*2**9 + $2*2**8 + $hexa2dec{$3}*16 + $hexa2dec{$4};
		return $num;
	} elsif ($string =~ /x.(\d|\w)(\d|\w)(\d|\w)(\d|\w)./) {
		$num = $hexa2dec{$1}*16**3 + $hexa2dec{$2}*16**2 + $hexa2dec{$3}*16 + $hexa2dec{$4};
		return $num;
	}
	return "";
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
			$r_A_num = dec_to_10bit($r_A_num);
			$r_D_num = dec_to_10bit($r_D_num);
			$r_B_num = dec_to_16bit($r_B_num);
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
			$r_A_num = dec_to_10bit($r_A_num);
			$r_D_num = dec_to_10bit($r_D_num);
			if ($r_B_num =~ /\b\d+\b/) {
				$r_B_num = dec_to_16bit($r_B_num);
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
			$r_A_num = dec_to_10bit($r_A_num);
			$r_D_num = dec_to_10bit($r_D_num);
			$r_B_num = dec_to_16bit(0);
		} elsif (defined $assembly{"$cmd,,$r_D,$r_A"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,,$r_D,$r_A"});
			$r_A_num = dec_to_10bit($r_D_num);
			$r_D_num = dec_to_10bit(0);
			$r_B_num = dec_to_16bit($r_A_num);
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
			$r_A_num = dec_to_10bit(0);
			$r_D_num = dec_to_10bit($r_D_num);
			$r_B_num = dec_to_16bit($r_B_num) if ($r_B_num =~ /\b\d+\b/);
		} elsif (defined $assembly{"$cmd,,$r_D,IMM"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,,$r_D,IMM"});
			$r_A_num = dec_to_10bit($r_D_num);
			$r_D_num = dec_to_10bit(0);
			$r_B_num = dec_to_16bit($r_B_num) if ($r_B_num =~ /\b\d+\b/);
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
			$r_A_num = dec_to_10bit(0);
			$r_D_num = dec_to_10bit($r_D_num);
			$r_B_num = dec_to_16bit(0);
		} else {
			print "ERROR! Could not interpert the following line:\n$line\n";
			return "";
		}
	#case without input registers
	} elsif ($line =~ /\s*(\S+)\s*/) {
		$cmd = $1;
		if (defined $assembly{"$cmd,,,"}) {
			($opcode, $subopcode) = split(',', $assembly{"$cmd,,,"});
			$r_A_num = dec_to_10bit(0);
			$r_D_num = dec_to_10bit(0);
			$r_B_num = dec_to_16bit(0);
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
		$r_D_num = hexa_to_dec($2);
		$r_A_num = hexa_to_dec($3);
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
			$r_B_num = hexa_to_dec($r_B_num);
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
	} else {
		print "ERROR! The following line could not be interperted:\n$line\n";
		return "";
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
	while ($line !~ /\s*package \S+ is\s*/) {
		$line = <$fd>;
	}
	while ($line = <$fd>) {
		chomp($line);
		if ($line =~ /\s*constant.*/) {
			constant_VHDL_to_assembly($line);
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
		chomp($line);
		if ($line =~ /\s*end\s*/) {
			unshift @constants, "\tconstant KERNEL_LEN\t\t: integer := $address;\n";
			return;
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
		chomp($line);
		if ($line =~ /\s*constant.*/) {
			constant_assembly_to_VHDL($line);
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
