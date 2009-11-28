
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'Business-OnlinePayment-Protx',
  NAME      => 'Business::OnlinePayment::Protx',
  AUTHOR    => 'Simon\ Elliott\ \<cpan\@browsing\.co\.uk\>',
  ABSTRACT  => 'DEPRECATED\ \-\ See\ Business\-OnlinePayment\-SagePay',
  VERSION   => '0.06',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "Test::More" => '0',
    "Net::SSLeay" => '1.35',
    "Data::Dumper" => '0',
    "Business::OnlinePayment" => '2.01',
  },
  test => {TESTS => 't/*.t'}
);

