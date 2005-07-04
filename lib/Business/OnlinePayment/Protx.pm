package Business::OnlinePayment::Protx;

=head1 NAME

Business::OnlinePayment::Protx - Perl Class for making Online Payments via Protx VPS

=head1 SYNOPSIS

  use Business::OnlinePayment::Protx;

  Business::OnlinePayment::Protx->Vendor($your_vps_gateway_username);

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

  my $payment_status = $request->Status;

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



  my $status = $request->make_preauth_payment( VendorTxCode => '1231', Amount => ... );
  my $preauth_VPSRef = $repeat_request->VPSTxId;
  my $preauth_VendorRef = $repeat_request->VendorTxCode;


=head1 DESCRIPTION

Business::OnlinePayment::Protx is a module that allows you to easily make
payments via the Protx VPS DirectPay system.

This module provides a Flexible powerful class with attributes matching the
fields used in VPS request and response messages. It uses LWP to send HTTPS
POST requests to the gateway and processes the response.

=cut

use 5.006;
use strict;
use Data::Dumper;
our $VERSION = '0.03';

use LWP::UserAgent;

use base qw(Class::Accessor Class::Fields Class::Data::Inheritable);

use public qw(VendorTxCode Amount Description CardHolder CardNumber
              StartDate ExpiryDate IssueNumber CV2 CardType
              Status SecurityKey TxAuthNo VPSTxId
              RelatedVPSTxId RelatedVendorTxCode RelatedSecurityKey RelatedTxAuthNo);

use private qw( _lwp);

my %servers = (
	       live => {
			payment => 'https://ukvps.protx.com/vpsDirectAuth/PaymentGateway.asp',
			service => 'https://ukvps.protx.com/vps200/dotransaction.dll?Service=',
		       },
	       test => {
			payment => 'https://ukvpstest.protx.com/vpsDirectAuth/PaymentGateway.asp',
			service => 'https://ukvpstest.protx.com/vps200/dotransaction.dll?Service=',
		       },
	       simulator => {
			     payment => 'https://ukvpstest.protx.com/VSPSimulator/VSPDirectGateway.asp',
			     service => 'https://ukvpstest.protx.com/VSPSimulator/VSPServerGateway.asp?Service=',
			    },
	      );

__PACKAGE__->mk_ro_accessors( qw{Status SecurityKey TxAuthNo VPSTxId});
__PACKAGE__->mk_accessors( qw{VendorTxCode Amount Description CardHolder CardNumber
                              StartMonth StartYear ExpiryMonth ExpiryYear IssueNumber CV2 CardType
                              Status SecurityKey TxAuthNo VPSTxId
                              RelatedVPSTxId RelatedVendorTxCode RelatedSecurityKey RelatedTxAuthNo} );


__PACKAGE__->mk_classdata('VPSProtocol');
__PACKAGE__->VPSProtocol('2.22');
__PACKAGE__->mk_classdata('Vendor');
__PACKAGE__->mk_classdata('Currency');
__PACKAGE__->Currency('GBP');
__PACKAGE__->mk_classdata('mode');
__PACKAGE__->mode('simulator');

########################################

=head1 CLASS METHODS

=head2 Vendor

This class method specifies the vendor username to be used in payment requests.

  Business::OnlinePayment::Protx->Vendor($your_vps_gateway_username);

This needs to be set before creating or using any objects.

=head2 VPSProtcol

This class method specifies the VPS protocol to be used in payment requests.

  Business::OnlinePayment::Protx->VPSProtocol('2.22');

The default is 2.2, if you need to change the value, do so before calling an object method that uses it
such as make_direct_payment

=head2 mode

This class method specifies the mode to be used for payment requests.

  Business::OnlinePayment::Protx->mode('live');

The default mode value is 'simulator', other modes are 'test' and 'live'.

=head1 CONSTRUCTOR METHODS

=head2 new

This creates and populates the Business::OnlinePayment::Protx with parameters provided.

my $request = Business::OnlinePayment::Protx->new();

Parameters you can provide are Vendor

=cut

sub new {
  my $class = shift;
  my %params = @_;
  my $object = {
		VPSProtocol => $class->VPSProtocol,
		Currency => $class->Currency,
		Vendor => $class->Vendor || $params{Vendor},
		_lwp => LWP::UserAgent->new(timeout=>4),
	       };

  die "Vendor username needs to be set, please read the documentation\n" unless (__PACKAGE__->Vendor || $params{Vendor});
  my $self = bless ($object, ref $class || $class);
  return $self;
}

########################################

=head1 OBJECT METHODS AND ACCESSORS

=head2 make_direct_payment

This method sends a payment request to the VPS Payment Gateway and checks the result.

This method takes the following named arguments : VendorTxCode, Amount, Description, CardHolder, CardNumber,
StartMonth, StartYear, ExpiryMonth, ExpiryYear, IssueNumber, CV2, CardType
and returns true (the Status provided by the gateway) on success
and dies on failure.

This method is called on the object and will update the object based on the results,
these results can then be accessed via the normal accessors as show below

my $status = $request->make_direct_payment( VendorTxCode => '1231', Amount => ... );

my $VPS_tx_id = $request->VPSTxId;

=cut

sub make_direct_payment {
  my ($self, %params) = @_;
  foreach my $field (qw(VendorTxCode Description CardHolder CardNumber IssueNumber CV2 CardType Amount StartMonth StartYear ExpiryMonth ExpiryYear)) {
    $self->$field($params{$field});
  }
  my $status = $self->_process_transaction( TxType => 'PAYMENT' );
  return $status;
}


=head2 make_repeat_payment

This method sends a repeat payment request to the VPS Payment Gateway and checks the result.

This method takes the following arguments : VendorTxCode, Description, Amount,
RelatedVPSTxId, RelatedVendorTxCode, RelatedSecurityKey, RelatedTxAuthNo
and returns true (the Status provided by the gateway) on success
and dies on failure.

This method is called on the object and will update the object based on the results,
these results can then be accessed via the normal accessors as show below

my $status = $request->make_repeat_payment(VendorTxCode=>...);

my $VPS_tx_id = $request->VPSTxId;

=cut

sub make_repeat_payment {
  my ($self, %param) = @_;
  foreach my $field (qw(VendorTxCode Description Amount )) {
    $self->$field($param{$field});
  }

  my $status = $self->_process_transaction( TxType => 'REPEAT',
					    RelatedVPSTxId => $param{RelatedVPSTxId},
					    RelatedVendorTxCode => $param{RelatedVendorTxCode},
					    RelatedSecurityKey => $param{RelatedSecurityKey},
					    RelatedTxAuthNo => $param{RelatedTxAuthNo},);
  return $status;
}

=head2 make_preauth_payment

This method sends a preauthorise payment request to the VPS Payment Gateway and checks the result.

This method takes the following named arguments : VendorTxCode, Amount, Description, CardHolder, CardNumber,
StartMonth, StartYear, ExpiryMonth, ExpiryYear, IssueNumber, CV2, CardType
and returns true (the Status provided by the gateway) on success
and dies on failure.

This method is called on the object and will update the object based on the results,
these results can then be accessed via the normal accessors as show below

my $status = $request->make_preauth_payment( VendorTxCode => '1231', Amount => ... );

my $VPS_tx_id = $request->VPSTxId;

=cut

sub make_preauth_payment {
  my ($self, %params) = @_;
  foreach my $field (qw(VendorTxCode Description CardHolder CardNumber IssueNumber CV2 CardType Amount StartMonth StartYear ExpiryMonth ExpiryYear)) {
    $self->$field($params{$field});
  }
  my $status = $self->_process_transaction( TxType => 'PREAUTH' );
  return $status;
}

=head2 make_deferred_payment

This method sends a deferred payment request to the VPS Payment Gateway and checks the result.

=cut

sub make_deferred_payment {
  my ($self, %params) = @_;
  foreach my $field (qw(VendorTxCode Description CardHolder CardNumber IssueNumber CV2 CardType Amount StartMonth StartYear ExpiryMonth ExpiryYear)) {
    $self->$field($params{$field});
  }
  my $status = $self->_process_transaction( TxType => 'DEFERRED' );
  return $status;
}

=head2 abort_deferred_payment

This method sends a repeat payment request to the VPS Payment Gateway and checks the result.

=cut

sub abort_deferred_payment {


}

=head2 release_deferred_payment

This method sends a repeat payment request to the VPS Payment Gateway and checks the result.

=cut

sub release_deferred_payment {


}

##################################################################
# Attributes and Accessors

=head2 CardType

Type of card used on order

VISA, MC (mastercard), DELTA, SOLO, SWITCH, UKE (electron), AMEX, DC or JCB

alphanumeric

=head2 Amount

Total Value of Order

floating point to 2 decimal places.

=cut

sub get_Amount {
  my $amount = shift->{Amount};
  return sprintf("%.2f",$amount);
}

sub Amount {
  my $self = shift;
  my $amount = shift;
  if ($amount) {
    $self->{Amount} = $amount;
  } else {
    $amount = $self->{Amount};
  }
  return sprintf("%.2f",$amount);
}

=head2 StartMonth

=head2 StartYear

=head2 StartDate

alias to get_StartDate

=head2 get_StartDate

=cut

sub StartDate {
  get_StartDate(shift);
}

sub get_StartDate {
  my $self = shift;
  return 0 unless (defined $self->{StartMonth});
  return sprintf("%02d%02d",$self->StartMonth,$self->StartYear);
}

=head2 ExpiryMonth

=head2 ExpiryYear

=head2 ExpiryDate

alias to get_ExpiryDate

=head2 get_ExpiryDate

=cut

sub ExpiryDate {
  get_ExpiryDate(shift);
}

sub get_ExpiryDate {
  my $self = shift;
  return sprintf("%02d%02d",$self->ExpiryMonth, $self->ExpiryYear);
}

########################################
# private / internal methods

# _process_transaction( TxType => , ... );

sub _process_transaction {
  my ($self,%params) = @_;
  my $class = ref $self;

  # populate POST Form
  my %form = map { $_ => $params{$_} } keys %params;
  @form{qw(VPSProtocol Currency Vendor)} = ($class->VPSProtocol, $class->Currency, $class->Vendor);
  foreach (qw(StartDate ExpiryDate VendorTxCode Description CardHolder CardNumber IssueNumber CV2 CardType Amount)) {
    $form{$_} = $self->$_ if ($self->$_);
  }
  delete $form{StartDate} unless ($form{StartDate} > 1);

#  warn "[WARN] : form values :\n";
#  warn Dumper(%form);

  # send POST Form and get response
  my $url = ($params{TxType} =~ /(?:PAYMENT|DEFERRED|PREAUTH)/) ?
    $servers{$class->mode}{'payment'} : $servers{$class->mode}{'service'} .'Vendor'. ucfirst(lc$params{TxType}) .'Tx' ;
  warn "[WARN] : url is $url\n";
  my $response = $self->{_lwp}->post( $url , \%form );

  # process response and catch errors
  my $return;
  if ($response->is_success) {
    my $response_fields = $self->_parse_response($response->content);
    my ($status, $statusdetail,$vpstxid, $authno, $seckey)
      = @$response_fields{qw(Status StatusDetail VPSTxId TxAuthNo SecurityKey )};
    # check status field for OK, MALFORMED or INVALID
    STATUS : {
	$self->{Status} = $status;
	if ( $status eq 'OK' ) {
	    $self->{SecurityKey}= $seckey;
	    $self->{TxAuthNo} = $authno;
	    $self->{VPSTxId}= $vpstxid;
	    last STATUS;
	}
	if ( $status eq 'ERROR') {
	    warn "[WARNING] request received ERROR status : $statusdetail\n";
	    $self->{StatusDetail} = $statusdetail;
	    last STATUS;
	}
	if ( $status eq 'NOTAUTHED') {
	    warn "[WARNING] request received NOTAUTHED status : $statusdetail\n";
	    $self->{StatusDetail} = $statusdetail;
	    last STATUS;
	}
	if ( $status eq 'REJECTED') {
	    warn "[WARNING] request received REJECTED status : $statusdetail\n";
	    $self->{StatusDetail} = $statusdetail;
	    last STATUS;
	}
	if ($status eq 'INVALID') {
	    warn "[ERROR] request was invalid : $statusdetail";
	    $self->{StatusDetail} = $statusdetail;
	    last STATUS;
	}
	if ($status eq 'MALFORMED') {
	    warn "[ERROR] request was malformed : $statusdetail";
	    $self->{StatusDetail} = $statusdetail;
	    last STATUS;
	}
	else {
	    die "[ERROR] unrecognised status : $status : $statusdetail";
	}
      } # end of STATUS
    $return = $status;
  }
  else {
      $self->{Status} = 'SENDING_ERROR';
      $self->{StatusDetail} = $response->status_line;
      warn "[ERROR] unable to complete request/response with protx server : " . $response->status_line;
      return $self->{Status};
  }
}

sub _parse_response {
  my ($self,$response) = @_;
  my $crlfpattern = qq{[\015\012\n\r]};
  my %values = map { split(/=/,$_) } grep(/=.+$/,split (/$crlfpattern/,$response));
  return \%values;
}

################################################################################

1;

__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

www.protx.com

=head1 AUTHOR

Foresite Developers, E<lt>dev@fsite.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 Foresite Business Solutions www.fsite.com

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
