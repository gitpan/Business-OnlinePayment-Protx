#/usr/bin/perl -w

use strict;

use Business::OnlinePayment::Protx;

Business::OnlinePayment::Protx->Vendor('username');

print "\n\nsending repeat request\n";

my ($vpstxid, $seckey, $authno);

my $repeat_request = $request->new();

my $repeat_status = $repeat_request->make_repeat_payment(
							 VendorTxCode => '2011',
							 Description => 'a repeat payment',
							 RelatedVPSTxId => $vpstxid,
							 RelatedVendorTxCode => '1011',
							 RelatedSecurityKey => $seckey,
							 RelatedTxAuthNo => $authno,
							 Amount => 250,
							);

my $repeat_VPSRef = $repeat_request->VPSTxId;
my $repeat_VendorRef = $repeat_request->VendorTxCode;
print "\nmade repeat payment : $repeat_status\n";
print "Vendor ref : $repeat_VendorRef ";
print "VPS ref : $repeat_VPSRef";
