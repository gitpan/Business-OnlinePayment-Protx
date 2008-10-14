package Business::OnlinePayment::Protx;

use strict;
use warnings;
use Carp;
use Net::SSLeay qw(make_form post_https);
use base qw(Business::OnlinePayment);

our $VERSION = '0.04';

# CARD TYPE MAP

my %card_type = (
	'american express' => 'AMEX',
	'amex' => 'AMEX',
	'visa' => 'VISA',
	'visa electron' => 'UKE',
	'visa debit' => 'VISA',
	'mastercard' => 'MC',
	'maestro' => 'MAESTRO',
	'switch' => 'MAESTRO',
	'switch solo' => 'SOLO',
	'solo' => 'SOLO',
	'diners club' => 'DINERS',
	'jcb' => 'JCB',
);

#ACTION MAP
my %action = (
    'normal authorization'    => 'PAYMENT',       # Take Payment now
    'authorization only'      => 'AUTHENTICATE',  # Store details at protx with 3D+address check
    'post authorization'      => 'AUTHORISE',	    # Post-Auth
    'refund'                  => 'REFUND',
);

my %servers = (
	live => {
		url => 'ukvps.protx.com',
		path => '/vspgateway/service/vspdirect-register.vsp',
		callback => '/vspgateway/service/direct3dcallback.vsp',
		authorise => '/vspgateway/service/authorise.vsp',
		refund => '/vspgateway/service/refund.vsp',
		port => 443,
	},
	test => {
		url  => 'ukvpstest.protx.com',
		path => '/vspgateway/service/vspdirect-register.vsp',
		callback => '/vspgateway/service/direct3dcallback.vsp',
		authorise => '/vspgateway/service/authorise.vsp',
		refund => '/vspgateway/service/refund.vsp',
		port => 443,
	},
	simulator => {
		url => 'ukvpstest.protx.com',
		path => '/VSPSimulator/VSPDirectGateway.asp',
		callback => '/VSPSimulator/VSPDirectCallback.asp',
		authorise => '/VSPSimulator/VSPServerGateway.asp?service=VendorAuthoriseTx ',
		refund => '/VSPSimulator/VSPServerGateway.asp?service=VendorRefundTx ',
		port => 443,
	},
);

sub callback {
	my ($self, $value) = @_;
	$self->{'callback'} = $value if $value;
	return $self->{'callback'};
}

sub set_server {
    my ($self, $type) = @_;
    $self->{'_server'} = $type;
    $self->server($servers{$type}->{'url'});
    $self->path($servers{$type}->{'path'});
    $self->callback($servers{$type}->{'callback'});
    $self->port($servers{$type}->{'port'});
}

sub set_defaults {
    my $self = shift;
	$self->set_server('live');

    $self->build_subs(qw/protocol currency cvv2_response postcode_response
       require_3d forward_to invoice_number authentication_key pareq cross_reference callback/);
	$self->protocol('2.22');
	$self->currency('GBP');
	$self->require_3d(0);
}

sub do_remap {
	my ($self, $content, %map) = @_;
	my %remapped = ();
	while (my ($k, $v) = each %map) {
		no strict 'refs';
		$remapped{$k} = ref( $map{$k} ) ? 
			${ $map{$k} }
			:
			$content->{$v};
	}
	return %remapped;
}

sub format_amount {
  my $amount = shift;
  return sprintf("%.2f",$amount);
}

sub submit_3d {
	my $self = shift;
        my %content = $self->content;
        my %post_data = (
          ( map { $_ => $content{$_} } qw(login password) ),
          MD    => $content{'cross_reference'},
          PaRes => $content{'pares'},
        );
	$self->set_server('test') if $self->test_transaction;
	my ($page, $response, %headers) = 
		post_https(
				$self->server,
				$self->port,
				$self->callback,
				undef,
				make_form(%post_data)
			);
	unless ($page) {
	  $self->error_message('There was a problem communicating with the payment server, please try later');
		return;
	}

  my $rf = $self->_parse_response($page);
	$self->server_response($rf);
	$self->result_code($rf->{'Status'});
	$self->authentication_key($rf->{'SecurityKey'});
	$self->authorization($rf->{'VPSTxId'});
	
	unless(
	  $self->is_success($rf->{'Status'} eq 'OK' ||
  	$rf->{'Status'} eq 'AUTHENTICATED' ||
    $rf->{'Status'} eq 'REGISTERED' 
    ? 1 : 0)) {
  		$self->error_message('Your card failed the password check.');
	}
}

sub auth_action {
	my $self = shift;
	my $action = shift;
	croak "Need vendor ID"
		unless defined $self->vendor;
	$self->set_server('test') if $self->test_transaction;
	my %content = $self->content();
	my %field_mapping = (
		VpsProtocol => \($self->protocol),
	  Vendor      => \($self->vendor),
	  TxType      => \($action{lc $content{'action'}}),
	  VendorTxCode=> 'invoice_number',
	  Description => 'description',
		Currency	=> \($self->currency),
	  Amount      => \(format_amount($content{'amount'})),
		RelatedVPSTxId => 'parent_auth',
		RelatedVendorTxCode => 'parent_invoice_number',
		RelatedSecurityKey => 'authentication_key',
	);
  my %post_data = $self->do_remap(\%content,%field_mapping);
	$self->path($servers{$self->{'_server'}}->{lc $post_data{'TxType'}});
	my ($page, $response, %headers) = 
		post_https(
				$self->server,
				$self->port,
				$self->path,
				undef,
				make_form(
					%post_data
				)
			);
	unless ($page) {
	  $self->error_message('There was a problem communicating with the payment server, please try later');
    $self->is_success(0);
		return;
	}

  my $rf = $self->_parse_response($page);
	$self->server_response($rf);
	$self->result_code($rf->{'Status'});
	$self->authorization($rf->{'VPSTxId'});
	unless($self->is_success($rf->{'Status'} eq 'OK'? 1 : 0)) {
		$self->error_message('There was a problem taking your payment');
	}

}

sub submit {
	my $self = shift;
	croak "Need vendor ID"
		unless defined $self->vendor;
	$self->set_server('test') if $self->test_transaction;
	my %content = $self->content();
	$content{'expiration'} =~ s#/##g;
	$content{'startdate'} =~ s#/##g if $content{'startdate'};

	my $card_name = $content{'name_on_card'}||$content{'first_name'} . ' ' . $content{'last_name'};
	my $customer_name = $content{'customer_name'}
	|| $content{'first_name'} ? $content{'first_name'} . ' ' . $content{'last_name'} : undef;
	
	my %field_mapping = (
		VpsProtocol => \($self->protocol),
	  Vendor      => \($self->vendor),
	  TxType      => \($action{lc $content{'action'}}),
	  VendorTxCode=> 'invoice_number',
	  Description => 'description',
		Currency	=> \($self->currency),
    CardHolder  => \($card_name),
	  CardNumber  => 'card_number',
	  CV2         => 'cvv2',
		ExpiryDate	=> 'expiration',
		StartDate	=> 'startdate',
	  Amount      => \(format_amount($content{'amount'})),
		IssueNumber => 'issue_number',
		CardType	=> \($card_type{lc $content{'type'}}),
		ApplyAVSCV2 => 0,

		BillingAddress  => 'address',
		BillingPostCode => 'zip',
		CustomerName    => \($customer_name),
		ContactNumber   => 'telephone',
		ContactFax		=> 'fax',
		CustomerEmail	=> 'email',
	);
	
	my %post_data = $self->do_remap(\%content,%field_mapping);
	
	$self->path($servers{$self->{'_server'}}->{'authorise'}) if $post_data{'TxType'} eq 'AUTHORISE';
	my ($page, $response, %headers) = 
		post_https(
				$self->server,
				$self->port,
				$self->path,
				undef,
				make_form(
					%post_data
				)
			);
	unless ($page) {
	  $self->error_message('There was a problem communicating with the payment server, please try later');
    $self->is_success(0);
		return;
	}

  my $rf = $self->_parse_response($page);
	$self->server_response($rf);
	$self->result_code($rf->{'Status'});
	$self->authorization($rf->{'VPSTxId'});
	$self->authentication_key($rf->{'SecurityKey'});
	
	if($self->result_code eq '3DAUTH' && $rf->{'3DSecureStatus'} eq 'OK') {
		$self->require_3d(1);
		$self->forward_to($rf->{'ACSURL'});
		$self->pareq($rf->{'PAReq'});
		$self->cross_reference($rf->{'MD'});
	}
	$self->cvv2_response($rf->{'CV2Result'});
	$self->postcode_response($rf->{'PostCodeResult'});
	unless($self->is_success(
	  $rf->{'Status'} eq '3DAUTH' ||
	  $rf->{'Status'} eq 'OK' ||
	  $rf->{'Status'} eq 'AUTHENTICATED' ||
	  $rf->{'Status'} eq 'REGISTERED' 
	  ? 1 : 0)) {
      if($rf->{'StatusDetail'} =~ /5013/) {
    		$self->error_message('Your card has expired');
      } else {
    		$self->error_message('There was a problem taking your payment');
      }
	}
}

sub _parse_response {
  my ($self,$response) = @_;
  my $crlfpattern = qq{[\015\012\n\r]};
  my %values = map { split(/=/,$_, 2) } grep(/=.+$/,split (/$crlfpattern/,$response));
  return \%values;
}

=head1 NAME

Business::OnlinePayment::Protx - Protx backend for Business::OnlinePayment

=head1 SYNOPSIS

  use Business::OnlinePayment;

  my $tx = Business::OnlinePayment->new(
      "Protx",
      "username"  => "abc",
  );

  $tx->content(
      type           => 'VISA',
      login          => 'testdrive',
      password       => '',
      action         => 'Normal Authorization',
      description    => 'Business::OnlinePayment test',
      amount         => '49.95',
      invoice_number => '100100',
      customer_id    => 'jsk',
      first_name     => 'Jason',
      last_name      => 'Kohles',
      address        => '123 Anystreet',
      city           => 'Anywhere',
      state          => 'UT',
      zip            => '84058',
      card_number    => '4007000000027',
      expiration     => '09/02',
      cvv2           => '1234', #optional
      referer        => 'http://valid.referer.url/',
  );

  $tx->set_server('simulator'); #live, simulator or test(default)

  $tx->submit();

   if ($tx->is_success) {
       print "Card processed successfully: " . $tx->authorization . "\n";
   } else {
       print "Card was rejected: " . $tx->error_message . "\n";
   }

=cut

=head1 DESCRIPTION

This perl module provides integration with the Protx VSP payments system.

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-onlinepayment-protx at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-OnlinePayment-Protx>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::OnlinePayment::Protx

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-OnlinePayment-Protx>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Business-OnlinePayment-Protx>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Business-OnlinePayment-Protx>

=item * Search CPAN

L<http://search.cpan.org/dist/Business-OnlinePayment-Protx>

=back

=head1 SEE ALSO

L<Business::OnlinePayment>

=head1 AUTHOR

  purge: Simon Elliott <cpan@browsing.co.uk>

=head1 ACKNOWLEDGEMENTS

  To Airspace Software Ltd <http://www.airspace.co.uk>, for the sponsorship.

  To Wallace Reis, for comments and patches.

=head1 LICENSE

  This library is free software under the same license as perl itself.

=cut

1;