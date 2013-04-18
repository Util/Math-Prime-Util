package Math::Prime::Util::ECProjectivePoint;
use strict;
use warnings;
use Carp qw/carp croak confess/;

if (!defined $Math::BigInt::VERSION) {
  eval { require Math::BigInt;   Math::BigInt->import(try=>'GMP,Pari'); 1; }
  or do { croak "Cannot load Math::BigInt"; };
}

BEGIN {
  $Math::Prime::Util::ECProjectivePoint::AUTHORITY = 'cpan:DANAJ';
  $Math::Prime::Util::ECProjectivePoint::VERSION = '0.26';
}

# Pure perl (with Math::BigInt) manipulation of Elliptic Curves
# in projective coordinates.

sub new {
  my ($class, $a, $b, $n, $x, $z) = @_;
  $a = Math::BigInt->new("$a") unless ref($a) eq 'Math::BigInt';
  $b = Math::BigInt->new("$b") unless ref($b) eq 'Math::BigInt';
  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
  $x = Math::BigInt->new("$x") unless ref($x) eq 'Math::BigInt';
  $z = Math::BigInt->new("$z") unless ref($z) eq 'Math::BigInt';

  croak "n must be >= 2" unless $n >= 2;
  $a->bmod($n);
  $b->bmod($n);

  my $self = {
    a => $a,
    b => $b,
    n => $n,
    x => $x,
    z => $z,
    f => $n-$n+1,
  };

  bless $self, $class;
  return $self;
}

sub _add {
  my ($self, $x2, $z2, $x1, $z1, $xin, $n) = @_;

  my $u = ( ($x2 - $z2) * ($x1 + $z1) ) % $n;
  my $v = ( ($x2 + $z2) * ($x1 - $z1) ) % $n;

  my $puv = $u + $v;
  my $muv = $u - $v;

  return ( ($puv*$puv) % $n, ($muv*$muv * $xin) % $n );
}

sub _add3 {
  my ($self, $x1, $z1, $x2, $z2, $xin, $zin, $n) = @_;

  my $u = (($x2 - $z2) * ($x1 + $z1) ) % $n;
  my $v = (($x2 + $z2) * ($x1 - $z1) ) % $n;

  my $upv2 = (($u+$v) * ($u+$v)) % $n;
  my $umv2 = (($u-$v) * ($u-$v)) % $n;

  return ( ($upv2*$zin) % $n, ($umv2*$xin) % $n );
}

sub _double {
  my ($self, $x, $z, $n) = @_;

  my $u = $x + $z;   $u = ($u * $u) % $n;
  my $v = $x - $z;   $v = ($v * $v) % $n;
  my $w = $u - $v;

  return ( ($u*$v)%$n , ($w*($v+$w*$self->{'b'}))%$n );
}

sub mul {
  my ($self, $k) = @_;
  my $x = $self->{'x'};
  my $z = $self->{'z'};
  my $n = $self->{'n'};

  my ($x1, $x2, $z1, $z2);

  my $r = --$k;
  my $l = -1;
  while ($r != 1) { $r >>= 1; $l++ }
  if ($k & (1 << $l)) {
    ($x2, $z2) = $self->_double($x, $z, $n);
    ($x1, $z1) = $self->_add3($x2, $z2, $x, $z, $x, $z, $n);
    ($x2, $z2) = $self->_double($x2, $z2, $n);
  } else {
    ($x1, $z1) = $self->_double($x, $z, $n);
    ($x2, $z2) = $self->_add3($x, $z, $x1, $z1, $x, $z, $n);
  }
  $l--;
  while ($l >= 1) {
    if ($k & (1 << $l)) {
      ($x1, $z1) = $self->_add3($x1, $z1, $x2, $z2, $x, $z, $n);
      ($x2, $z2) = $self->_double($x2, $z2, $n);
    } else {
      ($x2, $z2) = $self->_add3($x2, $z2, $x1, $z1, $x, $z, $n);
      ($x1, $z1) = $self->_double($x1, $z1, $n);
    }
    $l--;
  }
  if ($k & 1) {
    ($x, $z) = $self->_double($x2, $z2, $n);
  } else {
    ($x, $z) = $self->_add3($x2, $z2, $x1, $z1, $x, $z, $n);
  }

  $self->{'x'} = $x;
  $self->{'z'} = $z;
  return $self;
}

sub add {
  my ($self, $other) = @_;
  croak "add takes a EC point"
    unless ref($other) eq 'Math::Prime::Util::ECProjectivePoint';
  croak "second point is not on the same curve"
    unless $self->{'a'} == $other->{'a'} &&
           $self->{'b'} == $other->{'b'} &&
           $self->{'n'} == $other->{'n'};

  ($self->{'x'}, $self->{'z'}) = $self->_add3($self->{'x'}, $self->{'z'},
                                              $other->{'x'}, $other->{'z'},
                                              $self->{'x'}, $self->{'z'},
                                              $self->{'n'});
  return $self;
}

sub double {
  my ($self) = @_;
  ($self->{'x'}, $self->{'z'}) = $self->_double($self->{'x'}, $self->{'z'}, $self->{'n'});
  return $self;
}

sub _extended_gcd {
  my ($a, $b) = @_;
  my $zero = $a-$a;
  my ($x, $lastx, $y, $lasty) = ($zero, $zero+1, $zero+1, $zero);
  while ($b != 0) {
    my $q = int($a/$b);
    ($a, $b) = ($b, $a % $b);
    ($x, $lastx) = ($lastx - $q*$x, $x);
    ($y, $lasty) = ($lasty - $q*$y, $y);
  }
  return ($a, $lastx, $lasty);
}

sub normalize {
  my ($self) = @_;
  my $n = $self->{'n'};
  my $z = $self->{'z'};
  #my ($f, $u, undef) = _extended_gcd( $z, $n );
  my $f = Math::BigInt::bgcd( $z, $n );
  my $u = $z->copy->bmodinv($n);
  $self->{'x'} = ( $self->{'x'} * $u ) % $n;
  $self->{'z'} = $n-$n+1;
  $self->{'f'} = ($f * $self->{'f'}) % $n;
  return $self;
}

sub a { return shift->{'a'}; }
sub b { return shift->{'b'}; }
sub n { return shift->{'n'}; }
sub x { return shift->{'x'}; }
sub z { return shift->{'z'}; }
sub f { return shift->{'f'}; }

sub is_infinity {
  my $self = shift;
  return ($self->{'x'}->is_zero() && $self->{'z'}->is_one());
}

sub copy {
  my $self = shift;
  return Math::Prime::Util::ECProjectivePoint->new(
    $self->{'a'}, $self->{'b'}, $self->{'n'}, $self->{'x'}, $self->{'z'});
}

1;

__END__


# ABSTRACT: Elliptic curve operations for projective points

=pod

=encoding utf8


=head1 NAME

Math::Prime::Util::ECProjectivePoint - Elliptic curve operations for projective points


=head1 VERSION

Version 0.26


=head1 SYNOPSIS

  # Create a point on a curve (a,b,n) with coordinates 0,1
  my $ECP = Math::Prime::Util::ECProjectivePoint->new($a, $b, $n, 0, 1);

  # scalar multiplication by k.
  $ECP->mul($k)

  # add two points on the same curve
  $ECP->add($ECP2)

  say "P = O" if $ECP->is_infinity();

=head1 DESCRIPTION

This really should just be in Math::EllipticCurve.

To write.


=head1 FUNCTIONS

=head2 new

  $point = Math::Prime::Util::ECProjectivePoint->new(a, b);

Returns a new curve defined by a and b.

=head2 a

=head2 b

=head2 n

Returns the C<a>, C<b>, or C<n> values that describe the curve.

=head2 x

=head2 z

Returns the C<x> or C<z> values that define the point on the curve.

=head2 f

Returns a possible factor found during EC multiplication.

=head2 add

Takes another point on the same curve as an argument and adds it this point.

=head2 double

Double the current point on the curve.

=head2 mul

Takes an integer and performs scalar multiplication of the point.

=head2 is_infinity

Returns true if the point is (0,1), which is the point at infinity for
the affine coordinates.

=head2 copy

Returns a copy of the point.

=head2 normalize

Performs an extended gcd operation to make C<z=1>.  If a factor of C<n> is
found it is put in C<f>.


=head1 SEE ALSO

L<Math::EllipticCurve::Prime>

This really should just be in a L<Math::EllipticCurve> module.

=head1 AUTHORS

Dana Jacobsen E<lt>dana@acm.orgE<gt>


=head1 COPYRIGHT

Copyright 2012-2013 by Dana Jacobsen E<lt>dana@acm.orgE<gt>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut