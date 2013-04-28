#!/usr/bin/perl -w
use strict;
use Time::Local;
use Date::Calc();

my $fActive = 1;


my $nTimerSec = 0;
if ($fActive == 1)
{
	my $nTimeInSec = time;
	# nächste mögliche Weckzeit berechnen (aktuelle Zeit + 10 min)
	my (undef, $nNextPossibleWakeUpMinute, $nNextPossibleWakeUpHour) = localtime( time + 10 * 60 );
	foreach (0..13)
	{
		my ($nWakeUpHour, $nWakeUpMinute) = GetWakeUpTimeForDay( $nTimeInSec );
		
		if ( (defined $nWakeUpHour) and (defined $nWakeUpMinute) )
		{
			if (   ($_ > 0) or 
				($nWakeUpHour > $nNextPossibleWakeUpHour) or 
				( ($nWakeUpHour == $nNextPossibleWakeUpHour) and ($nWakeUpMinute > $nNextPossibleWakeUpMinute) )  )
			{
				my (undef, undef, undef, $nDay, $nMonth, $nYear) = localtime( $nTimeInSec );
				$nTimerSec = timelocal( 0, $nWakeUpMinute, $nWakeUpHour, $nDay, $nMonth, $nYear );
				
				last;
			}
		}
		
		print "DEBUG: Next Day\r\n";
		
		# add one day
		$nTimeInSec += 24 * 3600
	}
	
	print "INFO: Next wake up time is ".localtime($nTimerSec)."\r\n";
}

print "INFO: Write new time to NVRAM.\n";
#print `nvram-wakeup -s $nTimerSec -A -C /etc/nvram-wakeup.conf`;

exit 0;


sub GetWakeUpTimeForDay
{
	my ($nTimeInSec) = @_;
	
	my (undef, undef, undef, $nDay, $nMonth, $nYear, $nWDay) = localtime( $nTimeInSec );
	
	my $nCW = Date::Calc::Week_Number( $nYear, $nMonth + 1, $nDay );
	# moday is the first day of a new week and not wednesday
	$nCW++ if ( ($nWDay == 1) or ($nWDay == 2) );
	$nCW--;
	
	my @anWakeUpTimeOfDay = ();
	
	if ($nWDay == 1)
	{
		# Montag
		if ( CheckCW($nCW, 14, 16, 18, 20, 21, 23, 24, 26) )
		{
			@anWakeUpTimeOfDay = ( 11, 30 );
		}
	}
	elsif ($nWDay == 2)
	{
		# Dienstag
		if ( CheckCW($nCW, 12..23, 25, 26) )
		{
			@anWakeUpTimeOfDay = ( 7, 5 );
		}
	}
	elsif ($nWDay == 3)
	{
		# Mittwoch
		if ( CheckCW($nCW, 12..15, 17..26) )
		{
			@anWakeUpTimeOfDay = ( 7, 5 );
		}
		elsif ( CheckCW($nCW, 12..26) )
		{
			@anWakeUpTimeOfDay = ( 11, 30 );
		}
	}
	elsif ($nWDay == 4)
	{
		# Donnerstag
		if ( CheckCW($nCW, 14..21, 23..26) )
		{
			@anWakeUpTimeOfDay = ( 11, 30 );
		}
	}
	elsif ($nWDay == 5)
	{
		# Freitag
		if ( CheckCW($nCW, 12..15, 17, 18, 20, 21, 23) )
		{
			@anWakeUpTimeOfDay = ( 7, 5 );
		}
	}
	
	return @anWakeUpTimeOfDay;
}

sub CheckCW
{
	my ($nIstCW, @aszSollCW) = @_;
	
	my $fCWMatches = 0;
	foreach my $szSollCW (@aszSollCW)
	{
		if ($szSollCW == $nIstCW)
		{
			$fCWMatches = 1;
			last;
		}
	}
	
	return $fCWMatches;
}


