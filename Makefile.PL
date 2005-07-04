use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Business::OnlinePayment::Protx',
    VERSION_FROM      => 'lib/Business/OnlinePayment/Protx.pm', # finds $VERSION
    PREREQ_PM         => {
				Class::Accessor => 0.19,
				Class::Fields => 0.2,
  				Class::Data::Inheritable =>0.02 ,
				Crypt::SSLeay => 0.51,
			 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
       ( AUTHOR         => 'foresite developers <dev@fsite.com>') : ()),
);
