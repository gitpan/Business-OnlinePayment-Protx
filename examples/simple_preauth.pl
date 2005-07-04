#/usr/bin/perl -w

use strict;

use Business::OnlinePayment::Protx;

Business::OnlinePayment::Protx->Vendor('username');

print "\n\nsending PREAUTH payment request\n";

my $request = Business::OnlinePayment::Protx->new();

my $payment_status = $request->make_preauth_payment(
						    VendorTxCode => 221135,
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


my ($vpstxid, $seckey, $authno);

my $repeat_request = $request->new();

my $repeat_status = $repeat_request->make_repeat_payment(
							 VendorTxCode => 221136,
							 Description => 'a repeat payment',
							 RelatedVPSTxId => $VPSRef,
							 RelatedVendorTxCode => $VendorRef,
							 RelatedSecurityKey => $request->SecurityKey,
							 RelatedTxAuthNo => $request->TxAuthNo,
							 Amount => 25,
							);

my $repeat_VPSRef = $repeat_request->VPSTxId;
my $repeat_VendorRef = $repeat_request->VendorTxCode;
print "\nmade repeat payment : $repeat_status\n";
print "Vendor ref : $repeat_VendorRef ";
print "VPS ref : $repeat_VPSRef";

