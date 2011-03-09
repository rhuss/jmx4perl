#!perl

use Test::More;

unless($ENV{RELEASE_TESTING}) {
    Test::More::plan(skip_all => 'these tests are for release candidate testing');
}

unless(eval "use Test::Pod; 1") {
    plan skip_all => "Test::Pod required for testing POD";
}

all_pod_files_ok(grep { !/OpenPGPVerifier/ } all_pod_files(qw(blib script)));
