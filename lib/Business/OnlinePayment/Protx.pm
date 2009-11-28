package Business::OnlinePayment::Protx;

use strict;
use warnings;

our $VERSION = '0.06';

=head1 NAME

Business::OnlinePayment::Protx - DEPRECATED (see Business::OnlinePayment::SagePay)

=head1 VERSION

version 0.06

=head1 SEE ALSO

L<Business::OnlinePayment>, L<Business::OnlinePayment::SagePay>

=head1 AUTHOR

  purge: Simon Elliott <cpan@browsing.co.uk>

=head1 ACKNOWLEDGEMENTS

  To Airspace Software Ltd <http://www.airspace.co.uk>, for the sponsorship.

  To Wallace Reis, for comments and patches.

=head1 LICENSE

  This library is free software under the same license as perl itself.

=cut

sub new {
    my $class = shift;
    warn($class . " is deprecated, update your application to use Business::OnlinePayment::SagePay");
}

1;
