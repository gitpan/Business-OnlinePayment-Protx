#/usr/bin/perl -w

use strict;

use Business::OnlinePayment::Protx;

Business::OnlinePayment::Protx->Vendor('username');

print "\n\nsending payment request\n";

my $request = Business::OnlinePayment::Protx->new();

my $payment_status = $request->make_direct_payment(
						   VendorTxCode => 1131,
						   Amount => 23.5,
						   Description => 'a test purchase' ,
						   CardHolder => 'mr fred elliot',
						   CardNumber => '4444333322221111',
						   ExpiryMonth => "07",
						   ExpiryYear => "05",
						   IssueNumber => 3,
						   CV2 => 555,
						   CardType => 'MC',);

my $VPSRef = $request->VPSTxId;
my $VendorRef = $request->VendorTxCode;

print "\nmade payment : $payment_status\n";
print "Vendor ref : $VendorRef ";
print "VPS ref : $VPSRef";
