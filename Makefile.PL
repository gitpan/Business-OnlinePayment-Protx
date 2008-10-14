use inc::Module::Install;

name     'Business-OnlinePayment-Protx';
all_from 'lib/Business/OnlinePayment/Protx.pm';

requires 'Test::More'              => 0;
requires 'Business::OnlinePayment' => 2.01;
requires 'Net::SSLeay'             => 1.35;

auto_install;

WriteAll;
