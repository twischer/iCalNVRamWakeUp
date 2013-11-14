#!/usr/bin/perl -w
#
# sudo apt-get install libtie-ical-perl
#
use strict;
use warnings;
use Time::Local;
use DateTime;
use iCal::Parser();
use Data::Dumper();

my $DEBUG					= 1;
my $ACTIVE					= 1;
my $LAST_WAKE_EVENT_HOUR	= 14;
my $WAKE_TIME_MIN_DIFF		= 1*60 + 35;

my $DEV                         = "/sys/class/rtc/rtc0/wakealarm";
#my $DEV                        = "/proc/acpi/alarm";              # Fuer Kernel < 2.6.22



my $ICAL_FILE= "/media/server/private/wischer/Backup/.kde/share/apps/korganizer/std.ics";
$ICAL_FILE= "/home/timo/.kde/share/apps/korganizer/std.ics" if ($DEBUG == 1);


my $nTimerSec = 0;
if ($ACTIVE == 1)
{
	my $pNextWakeTime = DateTime->today();
	# caluclate the date of the next wake up day
	if ( $pNextWakeTime->hour_1() >= $LAST_WAKE_EVENT_HOUR )
	{
		$pNextWakeTime->add( 'days' => 1 );
	}
	
	my $pParser = iCal::Parser->new( 'start'=> $pNextWakeTime );
	my $pmpEvents = $pParser->parse( $ICAL_FILE );
	
	
	# try to find the next valid appointment (exit after one week was tested)
	for (0..6)
	{
		# do not wake on saturday and sunday
		while ( $pNextWakeTime->day_of_week() == 6 || $pNextWakeTime->day_of_week() == 7 )
		{
			$pNextWakeTime->add( 'days' => 1 );
		}
		
		
		my $nDay = $pNextWakeTime->day();
		my $nMonth = $pNextWakeTime->month();
		my $nYear = $pNextWakeTime->year();
		my $pmpEventsOfDay = $pmpEvents->{"events"}->{$nYear}->{$nMonth}->{$nDay};
		
#		warn Data::Dumper::Dumper( $pmpEventsOfDay ) if ($DEBUG == 1);
		
		
		my $pChoosenWakeTime = undef;
		foreach my $pEvent (values %$pmpEventsOfDay)
		{
			my $szSummary = $pEvent->{"SUMMARY"};
			if ( $szSummary !~ m/BirthdayRemind/ )
			{
				my $pStartTime = $pEvent->{"DTSTART"};
				print $szSummary." ".$pStartTime->datetime()."\n";
				
				if ( $pStartTime->hour_1() < $LAST_WAKE_EVENT_HOUR )
				{
					if (  (not defined $pChoosenWakeTime) or ( DateTime->compare($pStartTime, $pChoosenWakeTime) < 0)  )
					{
						$pChoosenWakeTime = $pStartTime;
					}
				}
			}
		}
		
		if (defined $pChoosenWakeTime)
		{
			print "Use time ".$pChoosenWakeTime->datetime()."\n";
			
			$pChoosenWakeTime->subtract( 'minutes'=>$WAKE_TIME_MIN_DIFF );
			$nTimerSec = $pChoosenWakeTime->epoch();
			last;
		}
		else
		{
			# look in the next day
			$pNextWakeTime->add( 'days' => 1 );
		}
	}
	
	print "INFO: Next wake up time is ".localtime($nTimerSec)."\r\n";
}

print "INFO: Write new time to NVRAM.\n";
if ($DEBUG == 0)
{
	# Deactivate possibly old timer
	print `echo 0 > $DEV`;
	# Set new timer
	print `echo $nTimerSec > $DEV`;
	# print the result
	print `cat /proc/driver/rtc`;
}
