#!/usr/bin/perl
# Combine windows from umbrella sampling method
use strict;
use warnings;
# define separator  
my $xcol=1;
my $ycol=9;
my $overlapsize=20;
my $interpolsize=1000;

#my $numofargs=$#ARGV+1;
#print "Input arguments($numofargs):" ,"@ARGV\n";
#if ($numofargs%2!=0) {print "Wrong number of input parameters";exit;}

my @filenames;
my @filesizes;

##for (my $arg=0;$arg<$numofargs/2;$arg++){
##	push @filenames, shift(@ARGV);	
##	push @filesizes, shift(@ARGV);
##}
# columns start from 0 (perl)
open INFILE,"<",$ARGV[0] or die ("Unable to open file");
my $linecount=0;
while (my $inline=<INFILE>){
	chomp $inline;
	my ($name,$size)=split (/\s+/,$inline);
	push (@filenames,$name);
	push (@filesizes,$size);
}
print "Input filenames:\n";
print "@filenames\n";
print "Input filesizes:\n";
print "@filesizes\n";
if ($#filenames!=$#filesizes){
	exit;
}
my @FILEFIELDS;
for (my $fnum=0;$fnum<scalar @filenames;$fnum++){
	open  DATAFILE,"<",$filenames[$fnum] or die ("Unable to open file");
	#read all line of all files and store to @lines (grep : no empty lines no lines beginning with #)
	#each element in currentFile is one file line => $currentFile[0] is the first line of the file
	my @currentFile = map{ s/^\s+// ; s/\s+$//; $_ } grep !/^(?:#|$)/, <DATAFILE>;
	#split currentFile into elements and push it to filefields
	#FILEFIELDS is a 3d array [file][line][col];
	push @{ $FILEFIELDS[$fnum] }, map {[ split /\s+/ ]} @currentFile;
	close DATAFILE;
}

my @diffarray=(0);
for (my $file=0;$file<@FILEFIELDS-1;$file++){
	my @arrayfirst   = @{ $FILEFIELDS[$file]   };
	my @arraysecond  = @{ $FILEFIELDS[$file+1] }; 
#   store columns of first and second (next) file according to averlap size	

	my @xcolfirst    = map {$_->[$xcol]} @arrayfirst[$#arrayfirst-$overlapsize..$#arrayfirst];   
	my @ycolfirst    = map {$_->[$ycol]} @arrayfirst[$#arrayfirst-$overlapsize..$#arrayfirst];
	
	my @xcolsecond    = map {$_->[$xcol]} @arraysecond[0..$overlapsize];   
	my @ycolsecond    = map {$_->[$ycol]} @arraysecond[0..$overlapsize];

	#print "first\n";	
	#print1D(\@xcolfirst);
	#print1D(\@ycolfirst);
	#print "second\n";	
	#print1D(\@xcolsecond);
	#print1D(\@ycolsecond);
	
	my $xminfirst = $xcolfirst[0];
	my $xmaxfirst = $xcolfirst[@xcolfirst-1];		

	my $xminsecond = $xcolsecond[0];
	my $xmaxsecond = $xcolsecond[@xcolsecond-1];		
	
	my $xx1=$xminfirst+($xminfirst+$xmaxfirst)/1000;
	my $xx2=$xmaxsecond-($xminsecond+$xmaxsecond)/1000;

	print "xmin1=$xminfirst, xmax1=$xmaxfirst,xmin2=$xminsecond, xmax2=$xmaxfirst,dx1=$xx1,dx2=$xx2\n";
	my $diff=0;
	my $intSize=10000;
	my $deltaX=($xx2-$xx1)/$intSize;
	for (my $x=$xx1; $x<$xx2;$x+=$deltaX){
		my $yf=interpolate2Darray(\@xcolfirst,\@ycolfirst,$x);		
		my $ys=interpolate2Darray(\@xcolsecond,\@ycolsecond,$x);		
		#printf "%10.4f %10.4f %10.4f\n",$x,$yf,$ys;
		#difference between first and second matrix;
		#if diff>0 the second plot is more up
		$diff+=($ys-$yf);
	}
	$diff /=$intSize;
	
	push @diffarray, $diff;
	print "file:$file diff with next $diff\n";
}
open OUTTEST,">","diff.out";
printf OUTTEST "%20.10f\n",$diffarray[$_] for (0..@FILEFIELDS-1);
close OUTTEST;
#diffarray[i] contains diff of file i with file (i+1) 
for (my $d1=1;$d1<$#diffarray+1;$d1++){
	$diffarray[$d1] += $diffarray[$d1-1];	
}
my @combx;
my @comby;
my @xnonover;
my @ynonover;

for (my $file=0;$file<@FILEFIELDS;$file++){
	my @array   = @{ $FILEFIELDS[$file]   };

	my @xcol    = map {$_->[$xcol]} @array;   
	my @ycol    = map {$_->[$ycol]} @array;

	#@xcol =  map{"$_\n"} @xcol;
	
	@ycol =  map{$_-$diffarray[$file]} @ycol;	
	#@ycol =  @ycol;	
	
	push @combx, @xcol;
	push @comby, @ycol;
	push @xnonover,@xcol[0..$#xcol-$overlapsize];
	push @ynonover,@ycol[0..$#ycol-$overlapsize];
	
}
open OUT,">","combine.out";
for (my $i =0; $i<=$#combx;$i++){
	printf OUT "%13.6f\t%13.6f\n",$combx[$i],$comby[$i];	
}
close OUT;

open OUT,">","combine_noover.dat";
my $shiftvalue=0.0;
my $shiftvalues=20;
for (my $i =$#xnonover-$shiftvalues+1; $i<=$#xnonover;$i++){
	$shiftvalue+=$ynonover[$i];	
}
$shiftvalue /= $shiftvalues;
for (my $i =0; $i<=$#xnonover;$i++){
	printf OUT "%13.6f\t%13.6f\t%13.6f\n",$xnonover[$i],$ynonover[$i]-$shiftvalue,$shiftvalue;	
}
close OUT;

open OUT,">","combine.out";
for (my $i =0; $i<=$#combx;$i++){
	printf OUT "%13.6f\t%13.6f\t%13.6f\n",$combx[$i],$comby[$i]-$shiftvalue,$shiftvalue;	
}
close OUT;

sub print1D{
	my @array = @{ $_[0] };
	foreach (@array){
		print "$_\n";
	}
}

sub print2D{
	my @array=@_;
	foreach my $rowinfile (@array){
		foreach my $colinfile (@$rowinfile){
			print "$colinfile  ";
		}
		print "\n";
	}
}
sub interpolate2Darray{
	my ($xcol,$ycol,$x) = @_;
	my $result;
	my $i=0;
	my $a=($x-$xcol->[$i-1])/($xcol->[$i]-$xcol->[$i-1]);
	$result=$ycol->[$i-1]+$a*($ycol->[$i]-$ycol->[$i-1]);
}
