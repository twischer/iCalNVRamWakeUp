#!/usr/bin/perl -w
#
# sudo apt-get install libtie-ical-perl
#
use strict;
use Time::Local;
use Tie::iCal();
use Data::Dumper();

my $DEBUG					= 1;
my $ACTIVE					= 1;
my $LAST_WAKE_EVENT_HOUR	= 14;
my $WAKE_TIME_MIN_DIFF		= 1*60 + 15;


my $ICAL_FILE= "/media/server/private/wischer/Backup/.kde/share/apps/korganizer/std.ics";
$ICAL_FILE= "/home/timo/.kde/share/apps/korganizer/std.ics" if ($DEBUG == 1);


my $nTimerSec = 0;
if ($ACTIVE == 1)
{
	my %mpszEvents = ();
	tie %mpszEvents, 'Tie::iCal', $ICAL_FILE or die "Failed to tie file!\n";
	
	warn Data::Dumper::Dumper( \%mpszEvents ) if ($DEBUG == 1);
	
	my @aszWakeTimes = ();
	while (  my($szEventKey,$paszEvent) = each(%mpszEvents)  )
	{
		my $szEventName = $paszEvent->[0];
		
		if ($szEventName eq "VEVENT")
		{
			my $szTime = $paszEvent->[1]->{"DTSTART"};
			if (ref($szTime) eq "ARRAY")
			{
				$szTime = $szTime->[1];
			}
			
			if ( (defined $szTime) and ($szTime ne "") )
			{
				push @aszWakeTimes, $szTime;
			}
			else
			{
				warn "Could not determind date";
				warn Data::Dumper::Dumper( $paszEvent );
			}
		}
		elsif ( ($szEventName ne "VTODO") and ($szEventName ne "VJOURNAL") )
		{
			warn $szEventName;
		}
	}
	
	
	my $szLastDay = "";
	foreach my $szTime (sort @aszWakeTimes)
	{
		warn "Time: $szTime\n" if ($DEBUG == 1);
		
		if ($szTime =~ m/^(\d{4})(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)$/)
		{
			my $nYear = $1;
			my $nMonth = $2;
			my $nDay = $3;
			my $nHour = $4;
			my $nMinute = $5;
			my $nSecond = $6;
			
			
			# nur den ersten Termin des Tages nehmen
			my $szDay = $nYear.$nMonth.$nDay;
			next if ($szDay eq $szLastDay);
			$szLastDay = $szDay;
			
			
			my $nNewTimeInSec = timelocal( $nSecond, $nMinute, $nHour, $nDay, $nMonth-1, $nYear );
#			my @anDate = localtime( $nNewTimeInSec );
#			my $nDayOfWeek = $anDate[6];
#			# Sonntags und Samstags nicht wecken
#			 and ($nDayOfWeek != 0) and ($nDayOfWeek != 6)

			# nächste Zeit suchen welche in der Zukunft liegt
			if ( ($nNewTimeInSec > time) and ($nHour <= $LAST_WAKE_EVENT_HOUR) )
			{
				$nTimerSec = $nNewTimeInSec - $WAKE_TIME_MIN_DIFF * 60;
				last;
			}
		}
		else
		{
			warn "could not parse $szTime\n";
		}
	}
	
	untie %mpszEvents;
	
	print "INFO: Next wake up time is ".localtime($nTimerSec)."\r\n";
}

print "INFO: Write new time to NVRAM.\n";
if ($DEBUG == 0)
{
	print `nvram-wakeup -s $nTimerSec -A -C /etc/nvram-wakeup.conf`;
}
