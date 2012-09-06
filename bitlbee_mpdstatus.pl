# bitlbee set mpd status irssi perl script
# by gnomeye <gnomeye@gmail.com>
# credits to Erik Scharwaechter <diozaka@gmx.de>
#
# CHANGELOG:                                                          
#  0.1: First dev release
#######################################################################

use strict;
use IO::Socket;
use Irssi;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;

use vars qw{$VERSION %IRSSI %mpd};

$VERSION = "0.1";
%IRSSI = (
          name        => 'bitlbee_mpdstatus',
          authors     => 'gnomeye',
          contact     => 'gnomeye@gmail.com',
          license     => 'GPLv2',
          description => 'set your song as bitlbee status',
         );

sub print_error {
    my $msg = shift;
    Irssi::print("bitlbee_mpdstatus - ".$msg);
}

sub getuzictitle{
	my $url="http://www.uzic.ch/accueil.php";
	my $ua= LWP::UserAgent->new();
        my $req = HTTP::Request->new(GET=>$url);
        my $rsp = $ua->request($req);
        my $cnt=$rsp->content();
        if ($cnt=~/.*<marquee\ scrollamount\=3><b>(.*)<\/b>.*/){
		my $rt="uzic.ch: ".$1;
		return $rt;
	 	};
	 };

sub get_info {

    $mpd{'port'}    = Irssi::settings_get_str('mpd_port');
    $mpd{'host'}    = Irssi::settings_get_str('mpd_host');
    $mpd{'timeout'} = Irssi::settings_get_str('mpd_timeout');
    $mpd{'format'}  = Irssi::settings_get_str('mpd_format');
    $mpd{'status'}   = "";
    $mpd{'artist'}   = "";
    $mpd{'title'}    = "";

    my $sock = IO::Socket::INET->new(
                          Proto    => 'tcp',
                          PeerPort => $mpd{'port'},
                          PeerAddr => $mpd{'host'},
                          timeout  => $mpd{'timeout'}
                          );

    if (not $sock) {
        print_error('No MPD Server listening at port '.$mpd{'port'});
	return;
    }

    my $pat = "";
    my $tit = "";

    print $sock "status\n";
    while (not $pat =~ /^(OK$|ACK)/) {
        $pat = <$sock>;
        if ($pat =~ /state: (.+)$/) {
            $mpd{'status'} = $1;
        }
    }

    if ($mpd{'status'} ne "play") {
        $tit='';
	if (`ps axu | grep -v grep | grep mplayer | grep "http:\/\/128\.179\.101\.9"`){	
		$tit=getuzictitle();
	}
	else{
	print_error('not playing any music.');}
	close $sock;	
    }
    elsif ($mpd{'status'} eq "play") {

    print $sock "currentsong\n";
    $pat = "";
    while (not $pat =~ /^(OK$|ACK)/) {
        $pat = <$sock>;
        if ($pat =~ /Artist: (.+)$/) {
            $mpd{'artist'} = $1;
        } elsif ($pat =~ /Title: (.+)$/) {
            $mpd{'title'} = $1;
        }
    }

    close $sock;
    

    if ($mpd{'artist'} ne "" and $mpd{'title'} ne "") {
        $tit = $mpd{'format'};
	}
	
    $tit =~ s/\%ARTIST/$mpd{'artist'}/g;
    $tit =~ s/\%TITLE/$mpd{'title'}/g;
    }
    return $tit;
}
sub setstatus{
    	$mpd{'reftimeout'}    = Irssi::settings_get_str('mpd_statusref');
	$mpd{'mpdstatus'} = Irssi::settings_get_str('mpd_status');
	my $status = get_info();
	if ($mpd{'mpdstatus'} ne $status){
	Irssi::Irc::Server->command("MSG -bitlbee &bitlbee set status '$status'");
	Irssi::settings_set_str('mpd_status',$status);
}
	Irssi::timeout_add_once($mpd{'reftimeout'}*1000,'setstatus',undef);


}



sub help {
   print '
 bitlbee set mpd status 
=========================

by gnomeye (gnomeye@gmail.com)

credits to mpd.pl irssi script from
Erik Scharwaechter (diozaka@gmx.de)

VARIABLES
  mpd_host      The host that runs MPD (localhost)
  mpd_port      The port MPD is bound to (6600)
  mpd_timeout   Connection timeout in seconds (10)
  mpd_format    The text to display (%%ARTIST - %%TITLE)
  mpd_statusref Timeout to refresh status. (15)
  
USAGE
  /mpdstatus_set 	set mpd status (if it did not work automatically.)
  /mpdstatus_help       Print this text
';
}


Irssi::settings_add_str('mpdstatus', 'mpd_host', 'localhost');
Irssi::settings_add_str('mpdstatus', 'mpd_port', 6600);
Irssi::settings_add_str('mpdstatus', 'mpd_timeout', '10');
Irssi::settings_add_str('mpdstatus', 'mpd_format', '%ARTIST - %TITLE');
Irssi::settings_add_str('mpdstatus', 'mpd_statusref', '15');
Irssi::settings_add_str('mpdstatus', 'mpd_status', undef);

Irssi::command_bind('mpdstatus_set', 'setstatus');
Irssi::command_bind('mpdstatus_help', 'help');

Irssi::timeout_add_once(100,'setstatus',undef);
