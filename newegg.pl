#!/usr/bin/perl

use Mail::IMAPClient;
use IO::Socket::SSL;
use Data::Dumper;
use LWP::Simple;
use HTML::Entities;
use MIME::Parser;

$user = '';
$password = '';

sub parsenewegg {
  my ($link) = @_;

  $sanitized_link = decode_entities($1);
  $webpage = get($sanitized_link);
  $amount = 0;
  $code = 0;
  $pin = 0;

  for (split /^/, $webpage) {
    $row = $_;
    chomp $row;
    if ($row =~ /<span id="lblCertAmount" class="fntAmount">\$(\d+)\.\d+<\/span>/) {
      $amount = $1;
    } elsif ($row =~ /InitialBalance[^\d]+(\d+)/) {
      $amount = $1;
    } elsif ($row =~ /<img id="imgCertBarCode" src="\.\.\/barcodeimage\.ashx\?.+CBID=(\d+)&amp;/) {
      $code = $1;
    } elsif ($row =~ /CardNumber[^\d]+(\d+)/) {
      $code = $1;
    } elsif ($row =~ /<span id="lblPin" class="fntContent">(\d+)<\/span>/) {
      $pin = $1;
    } elsif ($row =~ /Pin[^\d]+(\d{4})/) {
      $pin = $1;
    }
  }

  print "$amount, $code, $pin\n";
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
    if ($email eq 'info@newegg.com') {
      my $parser = new MIME::Parser;
      $parser->parse_data($client->message_string($id));

      open(my $fh, $parser->filer->{MPF_Purgeable}[0]);

      while (my $row = <$fh>) {
        chomp $row;
        if ($row =~ /(https:\/\/www.vcdelivery.com\/Cert\/T2\/cert_MyCertificate.aspx[^"^>]+)/) {
          parsenewegg($1);
        }
      }
      close($fh);
      $parser->filer->purge;
    }
  }
}
$client->logout();
