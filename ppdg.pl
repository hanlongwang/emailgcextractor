#!/usr/bin/perl

no warnings::anywhere qw(uninitialized);

use Mail::IMAPClient;
use IO::Socket::SSL;
use MIME::Parser;
use Data::Dumper;
use LWP::Simple;
use JSON;

$user = '';
$password = '';

sub parseppdg {
  my ($link) = @_;

  my $webpage = get($link);
  my $first = 1;
  for ($webpage =~ /<script[^>]*>({.+})<\/script>/) {
    my $json = decode_json($1);
    print substr($json->{"cardDetails"}->{"itemValue"}, 1) . ", " . $json->{"cardDetails"}->{"giftCard"}->{"card_number"} . ", " . $json->{"cardDetails"}->{"giftCard"}->{"security_code"} . "\n";
  }
}

my $socket = IO::Socket::SSL->new(
   PeerAddr => 'imap.gmail.com',
   PeerPort => 993,
  )
  or die "socket(): $@";

my $client = Mail::IMAPClient->new(
   Socket   => $socket,
   User     => $user,
   Password => $password,
  )
  or die "new(): $@";

my $cont = 1;
$client->select('INBOX');
my @mails = ($client->unseen);
foreach my $id (@mails) {
  my $from = $client->get_header($id, 'From');
  if ($from =~ /([a-zA-Z\_\-\.0-9]+@[a-zA-Z\_\-0-9]+\.[0-9a-zA-Z\.\-\_]+)/) {
    my $email = lc $1;
    if ($email eq 'gifts@paypal.com') {
      my $parser = new MIME::Parser;
      $parser->parse_data($client->message_string($id));

      open(my $fh, $parser->filer->{MPF_Purgeable}[0]);

      while (my $row = <$fh>) {
        chomp $row;
        if ($row =~ /(https:\/\/www.paypal.com\/gifts\/claim\/[^\/]+\/)/) {
          parseppdg($1);
        }
      }
      close($fh);
      $parser->filer->purge;
    }
  }
}
$client->logout();
