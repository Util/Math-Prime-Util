#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Math::Prime::Util qw/primorial pn_primorial/;

my $broken64 = (18446744073709550592 == ~0);

my @pn_primorials = qw/
1
2
6
30
210
2310
30030
510510
9699690
223092870
6469693230
200560490130
7420738134810
304250263527210
13082761331670030
614889782588491410
32589158477190044730
1922760350154212639070
117288381359406970983270
7858321551080267055879090
557940830126698960967415390
40729680599249024150621323470
3217644767340672907899084554130
267064515689275851355624017992790
23768741896345550770650537601358310
2305567963945518424753102147331756070
232862364358497360900063316880507363070
23984823528925228172706521638692258396210
2566376117594999414479597815340071648394470
279734996817854936178276161872067809674997230
31610054640417607788145206291543662493274686990
/;

my @small_primorials = grep { $_ <= ~0 } @pn_primorials;

plan tests =>   0
              + 2 * (scalar @small_primorials)
              + 2 * (scalar @pn_primorials)
              + 2;

my @small_primes = qw/
2 3 5 7 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71
73 79 83 89 97 101 103 107 109 113 127 131 137 139 149 151 157 163 167 173
179 181 191 193 197 199 211 223 227 229 233 239 241 251 257 263 269 271 277 281
283 293 307 311 313 317 331 337 347 349 353 359 367 373 379 383 389 397 401 409
419 421 431 433 439 443 449 457 461 463 467 479 487 491 499 503 509 521 523 541
547 557 563 569 571 577 587 593 599 601 607 613 617 619 631 641 643 647 653 659
661 673 677 683 691 701 709 719 727 733 739 743 751 757 761 769 773 787 797 809
811 821 823 827 829 839 853 857 859 863 877 881 883 887 907 911 919 929 937 941
/;
sub nth_prime {
  my $n = shift;
  return 0 if $n <= 0;
  die "Out of range for fake nth_prime: $n" unless defined $small_primes[$n-1];
  $small_primes[$n-1];
}

# First we test native numbers
foreach my $n (0 .. $#small_primorials) {
  SKIP: {
    skip "Broken 64-bit again...", 2 if $broken64 && $n >= 14 && $n <= 15;
    is( primorial(nth_prime($n)), $pn_primorials[$n], "primorial(nth($n))" );
    is( pn_primorial($n), $pn_primorials[$n], "pn_primorial($n)" );
  }
}

# Then load up BigInt and make sure everything works for big numbers
require Math::BigInt;
foreach my $n (0 .. $#pn_primorials) {
  SKIP: {
    skip "Broken 64-bit again...", 2 if $broken64 && $n >= 14 && $n <= 15;
    is( primorial(nth_prime($n)), $pn_primorials[$n], "primorial(nth($n))" );
    is( pn_primorial($n), $pn_primorials[$n], "pn_primorial($n)" );
  }
}


is( primorial(100), '2305567963945518424753102147331756070', "primorial(100)");

is(
    primorial(541),
    '4711930799906184953162487834760260422020574773409675520188634839616415335845034221205289256705544681972439104097777157991804380284218315038719444943990492579030720635990538452312528339864352999310398481791730017201031090',
    "primorial(541)"
  );
