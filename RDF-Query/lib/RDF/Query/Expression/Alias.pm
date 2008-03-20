# RDF::Query::Expression::Alias
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Alias - Class for aliasing expressions with variable names

=cut

package RDF::Query::Expression::Alias;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Expression);

use Data::Dumper;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.000';
}

######################################################################

=head1 METHODS

=over 4

=cut

sub name {
	my $self	= shift;
	return $self->alias->name;
}

sub alias {
	my $self	= shift;
	return $self->op;
}

sub expression {
	my $self	= shift;
	return ($self->operands)[0];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(alias %s %s)',
		$self->op,
		map { $_->sse( $context ) } $self->operands,
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $alias	= $self->alias;
	my $expr	= $self->expression;
	return sprintf("(%s AS %s)", $expr->as_sparql, $alias->as_sparql);
}

=item C<< evaluate ( $query, $bridge, \%bound ) >>

Evaluates the expression using the supplied context (bound variables and bridge
object). Will return a RDF::Query::Node object.

=cut

sub evaluate {
	my $self	= shift;
	my $query	= shift;
	my $bridge	= shift;
	my $bound	= shift;
	my $expr	= $self->expression;
	my $value	= $expr->evaluate( $query, $bridge, $bound );
	return $value;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
