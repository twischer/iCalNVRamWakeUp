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
use LWP::UserAgent();

my $DEBUG					= 1;
my $ACTIVE					= 1;
my $LAST_WAKE_EVENT_HOUR	= 14;
my $WAKE_TIME_MIN_DIFF		= 1*60 + 35;

my $DEV                         = "/sys/class/rtc/rtc0/wakealarm";
#my $DEV                        = "/proc/acpi/alarm";              # Fuer Kernel < 2.6.22



my $ICAL_FILE= "http://www.google.com/calendar/ical/...\@gmail.com/private-.../basic.ics";


my $nTimerSec = 0;
if ($ACTIVE == 1)
{
	my $ua = LWP::UserAgent->new();
 	$ua->timeout(10);
 	$ua->env_proxy;
 	my $pICalData = $ua->get( $ICAL_FILE );
	
	my $pCurrentTime = DateTime->now();
	my $pParser = iCal::Parser->new( 'start'=> $pCurrentTime, 'no_todos' => 1 );
	my $pmpEvents = $pParser->parse_strings( $pICalData->decoded_content() );
	
	
	# try to find the next valid appointment (exit after one week was tested)
	my $pNextWakeTime = DateTime->today();
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
		
		warn Data::Dumper::Dumper( $pmpEventsOfDay ) if ($DEBUG == 2);
		
		
		my $pChoosenWakeTime = undef;
		foreach my $pEvent (values %$pmpEventsOfDay)
		{
			my $szSummary = $pEvent->{"SUMMARY"};
			if ( $szSummary !~ m/BirthdayRemind/ )
			{
				my $pStartTime = $pEvent->{"DTSTART"};
				print $szSummary." ".$pStartTime->datetime()."\n";
				
				# check if the event is early enough and in the future
				if ( $pStartTime->hour() < $LAST_WAKE_EVENT_HOUR and DateTime->compare($pStartTime, $pCurrentTime) > 0 )
				{
					# replace wake up event, if the current one was not defined yet or is later than the new found event
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
